import Foundation
import MLX
import MLXRandom
@preconcurrency import MLXLMCommon
@preconcurrency import MLXLLM
import Gemma4Swift

/// Moteur d'inférence MLX — équivalent de llm/LlmEngine.kt + ChatRepository.kt.
///
/// - Texte : `ChatSession` (mémoire multi-tour, system prompt FR).
/// - Multimodal (image + audio) : chemin manuel répliqué du CLI `describe`
///   (expansion des tokens `<|image|>`/`<|audio|>`, injection `pending*`,
///   génération via `MLXLMCommon.generate`). ChatSession est volontairement
///   contourné car il ne sait pas injecter les pixelValues/audio de Gemma 4.
///
/// Limite assumée : un tour multimodal est one-shot (sans historique de session) ;
/// les tours texte conservent l'historique. Le modèle reste -it et répond bien.
@MainActor
final class GemmaEngine {

    /// Instruction système (français), portée de LlmEngine.buildConversationConfig().
    static let systemPrompt =
        "Tu es Gemma, un assistant IA utile et concis. Réponds en français sauf demande contraire."

    private static let numImageTokens = 280
    private static let topP: Float = 0.95

    let model: Gemma4Pipeline.Model
    /// Paramètres de génération configurables (écran Réglages).
    var temperature: Float = 0.7
    var maxTokens: Int = 2048
    private var container: ModelContainer?
    private var session: ChatSession?

    init(model: Gemma4Pipeline.Model) {
        self.model = model
    }

    /// Vide le cache KV / GPU (action « Vider le cache » des réglages).
    func clearCaches() {
        session = nil
        MLX.GPU.clearCache()
    }

    var supportsImage: Bool { model.supportsImage }
    var supportsAudio: Bool { model.supportsAudio }
    var isLoaded: Bool { container != nil }

    static func isDownloaded(_ model: Gemma4Pipeline.Model) -> Bool {
        Gemma4ModelCache.isDownloaded(model)
    }

    /// Libère le modèle courant (utilisé avant un changement de modèle).
    func unload() {
        session = nil
        container = nil
        MLX.GPU.clearCache()
    }

    // MARK: - Chargement

    /// Télécharge (si besoin) puis charge le modèle. `onProgress` reçoit la
    /// fraction (0…1) et les octets pour l'écran de chargement.
    func load(onProgress: @escaping @Sendable (Double, Int64, Int64) -> Void) async throws {
        await Gemma4Registration.register(multimodal: true)

        if !Gemma4ModelCache.isDownloaded(model) {
            _ = try await Gemma4ModelDownloader.download(model) { p in
                onProgress(p.fraction, p.completedBytes, p.totalBytes)
            }
        } else {
            onProgress(1.0, 0, 0)
        }

        guard let path = Gemma4ModelCache.localPath(for: model) else {
            throw GemmaEngineError.modelNotFound(model.rawValue)
        }
        let loaded = try await loadModelContainer(from: path, using: Gemma4TokenizerLoader())
        self.container = loaded
    }

    /// Réinitialise la conversation (nouvelle session, sans recharger le modèle).
    func resetConversation() {
        session = nil
    }

    // MARK: - Génération texte (avec mémoire de session)

    func streamText(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                guard let container = self.container else {
                    continuation.finish(throwing: GemmaEngineError.notLoaded); return
                }
                let session = self.session ?? ChatSession(
                    container,
                    instructions: Self.systemPrompt,
                    generateParameters: GenerateParameters(
                        maxTokens: maxTokens,
                        temperature: temperature,
                        topP: Self.topP
                    )
                )
                self.session = session
                do {
                    for try await token in session.streamResponse(to: prompt) {
                        if Task.isCancelled { break }   // arrêt réel : on cesse de consommer
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Stop → l'annulation du Task interne fait cesser la consommation de
            // ChatSession, qui voit `.terminated` et stoppe la génération MLX.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Génération multimodale (image + audio)

    func streamMultimodal(prompt: String,
                          imagePath: String?,
                          audioPath: String?) -> AsyncThrowingStream<String, Error> {
        // Réinitialise la session texte : le tour multimodal est indépendant.
        session = nil
        let model = self.container
        let userPrompt = prompt.isEmpty ? Self.defaultPrompt(image: imagePath != nil, audio: audioPath != nil) : prompt
        // Capturées sur le MainActor : non lisibles depuis le bloc container.perform.
        let temp = temperature
        let maxTok = min(maxTokens, 1024)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let container = model else {
                        continuation.finish(throwing: GemmaEngineError.notLoaded); return
                    }

                    // 1. Pré-traitement des médias (hors du bloc actor).
                    var pixels: MLXArray?
                    if let imagePath {
                        pixels = try Gemma4ImageProcessor.processImage(url: URL(fileURLWithPath: imagePath))
                    }
                    var audio: Gemma4AudioProcessor.AudioFeatures?
                    if let audioPath {
                        audio = try await Gemma4AudioProcessor.processAudio(url: URL(fileURLWithPath: audioPath))
                    }

                    nonisolated(unsafe) let pixelsCapture = pixels
                    nonisolated(unsafe) let audioCapture = audio
                    let numAudioTokens = audio?.numTokens ?? 0

                    try await container.perform { context in
                        // 2. Contenu + placeholders (instruction FR repliée dans le prompt).
                        var parts: [String] = []
                        if pixelsCapture != nil { parts.append("<|image|>") }
                        if numAudioTokens > 0 { parts.append("<|audio|>") }
                        parts.append("\(Self.systemPrompt)\n\n\(userPrompt)")
                        let content = parts.joined(separator: "\n")
                        let messages: [[String: String]] = [["role": "user", "content": content]]

                        var ids = try context.tokenizer.applyChatTemplate(messages: messages)

                        // 3. Expansion des tokens spéciaux.
                        let imageTok = Int(Gemma4Processor.imageTokenId)
                        let audioTok = Int(Gemma4Processor.audioTokenId)
                        let boi = Int(Gemma4Processor.boiTokenId)
                        let eoi = Int(Gemma4Processor.eoiTokenId)
                        let boa = Int(Gemma4Processor.boaTokenId)
                        let eoa = Int(Gemma4Processor.eoaTokenId)
                        var expanded: [Int] = []
                        for tid in ids {
                            if tid == imageTok {
                                expanded.append(boi)
                                for _ in 0 ..< Self.numImageTokens { expanded.append(imageTok) }
                                expanded.append(eoi)
                            } else if tid == audioTok {
                                expanded.append(boa)
                                for _ in 0 ..< numAudioTokens { expanded.append(audioTok) }
                                expanded.append(eoa)
                            } else {
                                expanded.append(tid)
                            }
                        }
                        ids = expanded

                        // 4. Injection des données multimodales. On assigne toujours
                        //    les 3 champs (même nil) pour ne jamais laisser un média
                        //    résiduel d'un tour précédent, et on les remet à nil en
                        //    `defer` (robuste si `generate` échoue avant le 1er forward).
                        let mm = context.model as? Gemma4MultimodalLLMModel
                        mm?.pendingPixelValues = pixelsCapture
                        mm?.pendingAudioFeatures = audioCapture?.features
                        mm?.pendingAudioMask = audioCapture?.mask
                        defer {
                            mm?.pendingPixelValues = nil
                            mm?.pendingAudioFeatures = nil
                            mm?.pendingAudioMask = nil
                        }

                        // 5. Génération native (TokenIterator + sampler optimisé).
                        let lmInput = LMInput(tokens: MLXArray(ids.map { Int32($0) }))
                        let params = GenerateParameters(
                            maxTokens: maxTok,
                            temperature: temp,
                            topP: Self.topP
                        )
                        let stream = try MLXLMCommon.generate(input: lmInput, parameters: params, context: context)
                        for await generation in stream {
                            if Task.isCancelled { break }   // arrêt réel
                            switch generation {
                            case .chunk(let text): continuation.yield(text)
                            default: break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func defaultPrompt(image: Bool, audio: Bool) -> String {
        switch (image, audio) {
        case (true, true): return "Décris cette image et cet audio."
        case (true, false): return "Décris cette image."
        case (false, true): return "Transcris et résume cet audio."
        default: return "Bonjour"
        }
    }
}

enum GemmaEngineError: LocalizedError {
    case notLoaded
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .notLoaded: return "Le modèle n'est pas chargé."
        case .modelNotFound(let id): return "Modèle introuvable : \(id)"
        }
    }
}
