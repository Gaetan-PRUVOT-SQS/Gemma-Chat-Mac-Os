# GemmaChat macOS — Audit QA

> Audit rigoureux du 2026-06-25. Méthodo : tests unitaires + harnais fonctionnel headless
> + inférence réelle E4B + revue de code statique sur 3 perspectives indépendantes
> (moteur/concurrence, état/persistance, UI/markdown/accessibilité), puis triage adversarial
> et correctifs.

## 1. Résultats des tests (tous verts)

| Suite | Résultat |
|---|---|
| Tests unitaires maths (XCTest) | **15 / 15** |
| Harnais fonctionnel `--qa` (persistance, tombstone, mapping, markdown) | **20 / 20** |
| Inférence réelle `--probe` (texte / image / audio) | **OK** — texte FR cohérent, lecture image « GEMMA 42 », audio traité sans erreur |
| Build `xcodebuild` (app complète MLX) | **BUILD SUCCEEDED, 0 erreur** |

Lancer : `GemmaChat.app/Contents/MacOS/GemmaChat --qa` (tests logiques) et `… --probe` (inférence).

## 2. Défauts trouvés et statut

Sévérité : **C**ritique / **H**aute / **M**oyenne / **B**asse. Tous les défauts confirmés ont été corrigés.

### Corrigés

| # | Sév | Zone | Défaut | Correctif |
|---|----|------|--------|-----------|
| 1 | H | Moteur | **« Stop » n'arrêtait pas réellement MLX** : le `Task` interne du stream n'était pas annulé (retour de `yield` ignoré, pas d'`onTermination`) → génération jusqu'à `maxTokens`, et comme le `ModelContainer` sérialise les accès, la requête suivante se bloquait. | `continuation.onTermination → task.cancel()` + `if Task.isCancelled { break }` dans les deux chemins (texte/multimodal). L'arrêt de consommation déclenche `.terminated` côté ChatSession → MLX stoppe en ~1 token. |
| 2 | H | État | **Perte de données / état figé** en changeant de conversation pendant une génération : `new/open/delete` n'annulaient pas la génération ; persistance uniquement à la fin → tour perdu, `isGenerating` bloqué, tokens écrits dans un message disparu, re-sauvegarde de la mauvaise conversation. | `abortGenerationIfNeeded()` (annule + finalise + persiste avant le switch) ; `finishGeneration` gardé par `(isGenerating, conversationId == current)` ; tour utilisateur persisté dès l'envoi. |
| 3 | H | Persistance | **Résurrection d'une conversation supprimée** : `save`/`delete` en `Task` fire-and-forget sans ordre garanti → un `save` en vol recréait le fichier après `delete` (zombie au prochain lancement). | Tombstone `deletedIds` dans `ConversationStore` : un `save` post-`delete` est ignoré. (Régression couverte par `--qa`.) |
| 4 | M | État | **Titre générique** pour les conversations à pièce jointe : `ensureConversation(titleSeed:)` ignorait son paramètre (code mort) ; conversation invisible dans la barre latérale jusqu'à la fin de la génération. | `ensureConversation` upsert un résumé provisoire (titre « Image »/« Message vocal »/extrait), visible immédiatement et conservé par `persistCurrent`. |
| 5 | M | Moteur | **Fuite multimodale potentielle** : si `generate` échouait avant le 1er forward, `pendingPixelValues`/`audio` restaient → crash possible au tour suivant ; assignation asymétrique (audio seulement en `if let`). | Assignation systématique des 3 champs (même `nil`) + remise à `nil` en `defer`. |
| 6 | M | Markdown | **`**` non fermé** (état normal en streaming) était transformé en italique vide et les marqueurs disparaissaient (viole le contrat streaming-safe). | L'ouvrant italique exige `chars[i+1] != "*"`. (Régression `--qa` : `**gras` → littéral.) |
| 7 | M | Markdown | **Faux italiques** sur astérisques espacés (`a * b * c`, multiplications). | Règle de flanking : ouvrant non suivi d'une espace. (Régression `--qa` : `a * b * c` littéral.) |
| 8 | M | Accessibilité | **Boutons à icône seule muets** pour VoiceOver (Envoyer, Stop, Image, Micro, Retirer pièce jointe, Fermer). | `.accessibilityLabel` sur tous ; décorations (`GemmaLogo`/`GemmaGem`, point de statut) en `.accessibilityHidden(true)`. |
| 9 | M | UX | **Auto-scroll** ramenait l'utilisateur en bas à chaque token, empêchant de lire l'historique pendant la génération. | Suivi conditionnel via `onScrollGeometryChange` : ne suit que si déjà ~en bas ; un nouveau message réactive le suivi. |
| 10 | B | Image | Copies d'images **jamais nettoyées** (croissance disque). | `clearImage`/re-sélection suppriment la copie pendante non envoyée (les images rattachées à un message sont préservées). |
| 11 | B | Audio | Seuil min (~0,5 s) incohérent avec le libellé « 1s » ; fichier rejeté non supprimé. | Seuil aligné à ~1 s + suppression du rebut + `currentURL` nettoyé. |
| 12 | B | Probe | `--probe` renvoyait toujours 0 (inexploitable en CI). | `exit(1)` en cas d'échec. |

### Vérifié sain (pas de défaut)

- **Pas de crash du parseur markdown** sur entrées adverses / partielles (index de `numberedItem`, `heading`, `tokenize` correctement gardés — audité ligne à ligne).
- **Token spéciaux multimodaux** corrects (boi/eoi/boa/eoa, 280 tokens image) — conformes à la référence du package.
- **Le modèle auto-réinitialise** `pending*` au 1er forward (défaut #5 ne se déclenchait que sur échec précoce).
- **Captures `nonisolated(unsafe)` de `MLXArray`** : write-once, pas de data race réelle (même schéma que la référence du package).

## 3. Limites assumées (par conception, documentées)

- **Tours multimodaux one-shot** : envoyer une image/un audio réinitialise la session texte (le modèle ne garde pas l'historique pour ce tour). Améliorable en injectant l'historique dans le chemin manuel.
- **Mémoire de conversation au rechargement** : rouvrir une conversation réaffiche l'historique mais réinitialise le contexte du modèle (parité avec l'app Android/LiteRT).
- **Dynamic Type** : tailles de police fixes (pas de mise à l'échelle accessibilité système) — amélioration future possible.

## 4. Verdict

Aucun défaut bloquant résiduel. Les risques dominants identifiés par l'audit (arrêt qui n'arrêtait
pas, pertes de données / zombies de conversation en concurrence) sont corrigés et couverts par des
tests de non-régression. Build propre, 35 vérifications automatisées vertes, inférence trimodale
validée en conditions réelles.
