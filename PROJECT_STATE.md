# GemmaChat macOS — État du projet

> Portage natif macOS de l'app Android GemmaChat. Document de reprise / handoff.

## 1. Vue d'ensemble

Application **macOS native (SwiftUI)** de chat avec **Gemma 4 E4B**, 100 % locale
(hors-ligne), inférence via **MLX** (Apple Silicon). Portage 1:1 de l'app Android
`com.gaetan.gemmchat` (Kotlin/Compose, LiteRT-LM).

- **Dossier** : `~/Desktop/GemmaChat-macOS`
- **Cible** : Apple Silicon (M1+), macOS 15+, testé sur macOS 26 / 16 Go RAM
- **Bundle id** : `com.gaetan.gemmachat`
- **Modèle** : `mlx-community/gemma-4-e4b-it-4bit` (~5 Go, téléchargé au 1er lancement)

## 2. Pourquoi E4B et pas le 12B (décision clé)

L'utilisateur visait initialement le **Gemma 4 12B MLX**. Vérifié et écarté :

- `mlx-swift` officiel **n'implémente pas** l'architecture `gemma4` (issue ml-explore/mlx-swift #389).
- Le seul package qui le fait nativement en Swift, **`gemma-4-swift-mlx`** (VincentGourbin),
  couvre **E2B / E4B / 26B-A4B / 31B**. Le **12B « unified encoder-free »** y est présent dans
  l'enum mais marqué **`text-only` (todo multimodal)** — l'injection vision/audio du 12B suit un
  schéma différent non implémenté.
- L'app Android est **multimodale (image + audio)**. Pour garder cette parité **en Swift natif**,
  **E4B** est le bon choix : `capabilities = .anyToAny` (texte+image+audio+vidéo), package éprouvé.

Trois leviers (12B / Swift natif / multimodal complet) sont inconciliables aujourd'hui ; on a
sacrifié la taille (12B→E4B) pour garder natif + multimodal.

## 3. Dépendances & build

- **SPM** : `gemma-4-swift-mlx` (branch `main`) → tire `mlx-swift`, `mlx-swift-lm`,
  `swift-transformers`. Enregistre les types `gemma4` / `gemma4_text`.
- **Génération projet** : `xcodegen` (`project.yml`). Régénérer après ajout de fichiers :
  `xcodegen generate`.
- **Build** : **`xcodebuild`** (PAS `swift build` — MLX exige les shaders Metal). Xcode complet requis.
  ```bash
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild build -project GemmaChat.xcodeproj -scheme GemmaChat \
    -destination 'platform=macOS' -skipMacroValidation
  xcodebuild test  -project GemmaChat.xcodeproj -scheme GemmaChatTests \
    -destination 'platform=macOS' -skipMacroValidation   # 15 tests maths
  ```
  > Sur ce poste `xcode-select` pointe vers les Command Line Tools ; on force Xcode via
  > `DEVELOPER_DIR` (pas de `sudo` nécessaire).
- **Langage** : `SWIFT_VERSION = 5.0` côté app (concurrence stricte assouplie pour éviter les
  frictions Swift 6 avec les `MLXArray` non-Sendable). Le package compile dans son propre mode.

## 4. Architecture (mapping Android → Swift)

| Android | macOS |
|---|---|
| `llm/LlmEngine.kt` + `ChatRepository.kt` | `Inference/GemmaEngine.swift` |
| `data/StoredConversation.kt` | `Persistence/StoredConversation.swift` (schéma JSON **identique**) |
| `data/ConversationStore.kt` | `Persistence/ConversationStore.swift` (actor, FileManager/JSON) |
| `data/ModelPreferences.kt` | `Persistence/Preferences.swift` (UserDefaults) |
| `audio/AudioRecorder.kt` | `Audio/WavRecorder.swift` (AVAudioRecorder → WAV 16 kHz mono) |
| `ui/AppViewModel.kt` + `AppUiState.kt` | `ViewModel/ChatViewModel.swift` + `Models.swift` |
| `ui/ChatScreen/LoadingScreen/ConversationDrawer` | `Views/ChatView`, `LoadingView`, `ConversationSidebar` |
| `ui/components/MarkdownText.kt` | `Views/Markdown/MarkdownView.swift` |
| `ui/components/MarkdownPreprocess.kt` | `Views/Markdown/MathPreprocess.swift` (+ 15 tests XCTest) |
| `ui/theme/*` | `Theme/GemmaColors.swift`, `Typography.swift` (hex + polices repris à l'identique) |

Données dans `~/Library/Application Support/GemmaChat/` (conversations/, images/, recordings/).
Cache modèle : `~/Library/Caches/models/mlx-community/`.

## 5. Décisions techniques NON évidentes (pièges)

- **Texte vs multimodal séparés** dans `GemmaEngine` :
  - **Texte** → `ChatSession.streamResponse(to:)` (mémoire multi-tour, system prompt FR).
  - **Image + audio** → chemin **manuel** répliqué du CLI `describe` du package
    (`Gemma4ImageProcessor.processImage`, `Gemma4AudioProcessor.processAudio`, expansion des tokens
    `<|image|>`/`<|audio|>` avec boi/eoi/boa/eoa, injection `model.pendingPixelValues` /
    `pendingAudioFeatures` / `pendingAudioMask`, puis `MLXLMCommon.generate`).
    **ChatSession est volontairement contourné** : il ne sait pas injecter les pixelValues/audio de
    Gemma 4 (l'auteur du package le contourne aussi dans `chatStreamMultimodal`).
  - **Limite assumée** : un tour multimodal est one-shot (pas d'historique de session) ; les tours
    texte conservent l'historique. Rouvrir une conversation recharge l'UI mais réinitialise le
    contexte modèle (comme l'Android avec LiteRT).
- **Audio = WAV PCM 16 kHz mono.** Le préprocesseur lit via `AVAudioFile` (resample interne, max 30 s).
  On enregistre en `AVAudioRecorder` LinearPCM (conteneur WAV valide).
- **Sampler** : `temperature = 0.8`, `topP = 0.95` (aligné Android). `topK` non exposé par le package.
- **Polices** bundlées en TTF variables (Manrope, JetBrains Mono), **enregistrées par programme**
  (`CTFontManagerRegisterFontsForURL` au lancement) — 100 % local, pas de Google Fonts.
- **Téléchargement modèle** : géré par le package (`Gemma4ModelDownloader.download` + callback
  `Gemma4DownloadProgress.fraction`) → branché sur `LoadingView`. Pas de téléchargeur maison.
- **Micro** : `NSMicrophoneUsageDescription` dans Info.plist + `AVCaptureDevice.requestAccess(.audio)`.
- **Maths/LaTeX** : `cleanupMath` porté à l'identique (symboles → Unicode, indices/exposants),
  couvert par 15 tests (tous verts).

## 6. Fonctionnalités (parité Android)

Chat streaming + markdown (blocs code+copier, gras/italique/inline, titres, listes, maths) ·
multi-conversations persistées (sidebar : nouvelle/ouvrir/renommer/supprimer) · image (picker +
persistance locale) · audio (enregistrement WAV) · arrêt de génération (garde le partiel) ·
sélection/copie · horodatage · restauration de la dernière conversation au lancement.

## 7. Validation en conditions réelles (faite)

Inférence E4B testée de bout en bout via le harnais headless `--probe` (`GemmaChat/Probe.swift`,
lancer `GemmaChat.app/Contents/MacOS/GemmaChat --probe`) :

- **Texte** : explication de la photosynthèse en 3 phrases FR correctes (437 car, ~6 s). Sortie
  contenant du LaTeX (`$\text{CO}_2$`…) → confirme l'utilité de `cleanupMath`.
- **Image** : lecture correcte de « GEMMA 42 » dans une image générée (~5 s) → chemin vision OK.
- **Audio** : WAV 16 kHz traité et réponse produite sans erreur (~4 s) → pipeline audio OK.

Modèle en cache : `~/Library/Caches/models/mlx-community/gemma-4-e4b-it-4bit` (~4,9 Go).

> Audit QA complet (défauts trouvés/corrigés, méthodo, non-régression) : voir `QA_AUDIT.md`.
> Tests : `GemmaChat.app/Contents/MacOS/GemmaChat --qa` (logique) · `--probe` (inférence) ·
> `--shots` (rend les écrans en PNG) · `--gemshot`.

> **Redesign (déc. du design `Gemma Desktop (macOS)` PDF/PPTX)** — intégré :
> - **Onboarding** : `WelcomeView` (scan de compatibilité réel : RAM/puce/Neural Engine/disque via
>   `DeviceScan`) → choix du modèle (`ModelChoice` E2B recommandé / E4B qualité+) → `DownloadView`
>   (carte modèle, tags, %, vitesse/ETA, reprise auto, Pause/Annuler).
> - **Chat** : en-tête avec **sélecteur de modèle** (`ModelSwitcher`, bascule E2B↔E4B → recharge),
>   pastille « 100% local », accès **Réglages** ; accueil « Salut, moi c'est Gemma » + chips de
>   suggestions ; ligne de perf **tok/s mesuré**, bouton Arrêter rouge.
> - **Messages** : actions **Copier · Régénérer · Partager** (NSSharingServicePicker), avatar gemme.
> - **Barre latérale** : « Nouvelle discussion ⌘N », recherche ⌘K, conversations **groupées par date**,
>   statut modèle + accélérateur en bas.
> - **Réglages** (`SettingsView`) : accélérateur (info), **température** + **tokens max** (câblés au
>   sampler, persistés), stockage + vider le cache. Raccourcis ⌘N / ⌘↵.
> - Couleurs/typos déjà alignées sur le design (palette identique vérifiée dans le PPTX).
>
> **Non intégré (pas de fonctionnalité réelle derrière)** : système Skills/Agent, télémétrie
> °C / MTP / source d'alimentation, bascule matérielle Neural Engine/CPU (le moteur MLX tourne sur
> GPU Metal). Affichés au plus en informatif honnête.

## 8. Limites connues / suite possible

- Multimodal one-shot (cf. §5). Améliorable en injectant l'historique dans le path manuel.
- Auto-scroll simplifié (suit le bas pendant le streaming ; pas encore de pause-sur-scroll-up
  comme l'Android).
- 12B multimodal : à réévaluer si `gemma-4-swift-mlx` ajoute le path unified.
- Signature ad-hoc (`CODE_SIGN_IDENTITY = -`) pour usage local ; à configurer pour distribution.
- E4B 4-bit ≈ 5 Go : viser ≥ 16 Go RAM.
