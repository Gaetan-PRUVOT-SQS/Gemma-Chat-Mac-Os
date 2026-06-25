import Foundation
import SwiftUI
import AppKit
import Gemma4Swift

/// État + actions de l'app — équivalent de ui/AppViewModel.kt + AppUiState.kt.
@MainActor
final class ChatViewModel: ObservableObject {

    static let maxInputChars = 8000

    // Navigation / onboarding
    @Published var screen: AppScreen = .welcome
    @Published var scan: DeviceScan?

    // Téléchargement / chargement
    @Published var isDownloading = false
    @Published var downloadFraction: Double = 0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadSpeedBytesPerSec: Double = 0
    @Published var isPaused = false
    @Published var isInitializing = false
    @Published var loadError: String?

    // Modèle
    @Published private(set) var engine: GemmaEngine
    @Published var selectedModel: ModelChoice

    // Chat
    @Published var messages: [ChatMessage] = []
    @Published var conversations: [ConversationSummary] = []
    @Published var currentConversationId: String?
    @Published var isGenerating = false
    @Published var statusMessage: String?
    @Published var liveTokensPerSec: Double?
    @Published var searchQuery = ""
    @Published var showSettings = false

    // Réglages génération (écran Réglages)
    @Published var temperature: Double = Preferences.temperature {
        didSet { engine.temperature = Float(temperature); Preferences.temperature = temperature }
    }
    @Published var maxTokens: Int = Preferences.maxTokens {
        didSet { engine.maxTokens = maxTokens; Preferences.maxTokens = maxTokens }
    }

    // Saisie / pièces jointes
    @Published var inputText = ""
    @Published var pendingImagePath: String?
    @Published var pendingAudioPath: String?
    @Published var pendingAudioLabel: String?

    // Audio
    @Published var isRecordingAudio = false
    @Published var recordingElapsedMs: Int = 0

    private let store = ConversationStore.shared
    private let recorder = WavRecorder()
    private var generationTask: Task<Void, Never>?
    private var recordingTimer: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var lastSampleTime: Date?
    private var lastSampleBytes: Int64 = 0

    let accelerator = "GPU Metal"

    var supportsImage: Bool { engine.supportsImage }
    var supportsAudio: Bool { engine.supportsAudio }
    var modelDisplayName: String { selectedModel.name }
    var isModelDownloaded: Bool { GemmaEngine.isDownloaded(selectedModel.model) }
    var canSend: Bool {
        (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         || pendingImagePath != nil || pendingAudioPath != nil) && !isGenerating
    }

    /// ETA du téléchargement (secondes), nil si inconnu.
    var downloadETASeconds: Int? {
        guard downloadSpeedBytesPerSec > 0, totalBytes > 0 else { return nil }
        let remaining = Double(totalBytes - downloadedBytes)
        return max(0, Int(remaining / downloadSpeedBytesPerSec))
    }

    /// Conversations filtrées (recherche) et groupées par date pour la barre latérale.
    var groupedConversations: [(title: String, items: [ConversationSummary])] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? conversations : conversations.filter { $0.title.lowercased().contains(q) }
        let cal = Calendar.current
        let now = Date()
        var today: [ConversationSummary] = [], week: [ConversationSummary] = [], older: [ConversationSummary] = []
        for c in filtered {
            let d = Date(timeIntervalSince1970: Double(c.updatedAt) / 1000)
            if cal.isDateInToday(d) { today.append(c) }
            else if let days = cal.dateComponents([.day], from: d, to: now).day, days < 7 { week.append(c) }
            else { older.append(c) }
        }
        var out: [(String, [ConversationSummary])] = []
        if !today.isEmpty { out.append(("Aujourd'hui", today)) }
        if !week.isEmpty { out.append(("Derniers jours", week)) }
        if !older.isEmpty { out.append(("Plus ancien", older)) }
        return out
    }

    init() {
        let choice = ModelChoice.from(raw: Preferences.modelVariantRaw) ?? .e2b
        self.selectedModel = choice
        self.engine = GemmaEngine(model: choice.model)
        applySettings()
    }

    private func applySettings() {
        engine.temperature = Float(temperature)
        engine.maxTokens = maxTokens
    }

    func clearCache() {
        engine.clearCaches()
        statusMessage = "Cache vidé."
    }

    // MARK: - Onboarding / chargement

    func start() {
        // Déjà configuré et téléchargé → directement au chat.
        if Preferences.modelVariantRaw != nil, isModelDownloaded {
            loadModel()
        } else {
            runScan()
            screen = .welcome
        }
    }

    func runScan() {
        scan = DeviceScan.run(requiredGB: selectedModel.sizeGB,
                              recommendedRAMGB: selectedModel.recommendedRAMGB)
    }

    /// Choix du modèle depuis l'accueil → lance le téléchargement/chargement.
    func chooseModel(_ choice: ModelChoice) {
        selectedModel = choice
        Preferences.modelVariantRaw = choice.model.rawValue
        rebuildEngine()
        loadModel()
    }

    private func rebuildEngine() {
        engine.unload()
        engine = GemmaEngine(model: selectedModel.model)
        applySettings()
    }

    /// Télécharge (si besoin) puis charge le modèle sélectionné.
    func loadModel() {
        loadError = nil
        isPaused = false
        lastSampleTime = nil
        lastSampleBytes = 0
        let needsDownload = !isModelDownloaded
        screen = .download
        isDownloading = needsDownload
        isInitializing = !needsDownload
        downloadFraction = needsDownload ? 0 : 1

        loadTask = Task {
            do {
                try await engine.load { [weak self] fraction, done, total in
                    Task { @MainActor in self?.updateDownloadProgress(fraction, done, total) }
                }
                if Task.isCancelled { return }
                isDownloading = false
                isInitializing = false
                await restoreConversations()
                screen = .chat
            } catch {
                if Task.isCancelled { return }   // pause/annulation → pas d'erreur
                isDownloading = false
                isInitializing = false
                loadError = error.localizedDescription
            }
        }
    }

    private func updateDownloadProgress(_ fraction: Double, _ done: Int64, _ total: Int64) {
        downloadFraction = fraction
        downloadedBytes = done
        totalBytes = total
        let now = Date()
        if let t = lastSampleTime {
            let dt = now.timeIntervalSince(t)
            if dt > 0.5 {
                downloadSpeedBytesPerSec = max(0, Double(done - lastSampleBytes) / dt)
                lastSampleTime = now
                lastSampleBytes = done
            }
        } else {
            lastSampleTime = now
            lastSampleBytes = done
        }
        if fraction >= 1 { isDownloading = false; isInitializing = true }
    }

    func pauseDownload() {
        isPaused = true
        isDownloading = false
        loadTask?.cancel()
    }

    func resumeDownload() {
        // Le téléchargeur reprend automatiquement là où il s'était arrêté.
        loadModel()
    }

    func cancelDownload() {
        loadTask?.cancel()
        isDownloading = false
        isInitializing = false
        isPaused = false
        runScan()
        screen = .welcome
    }

    func retryLoad() {
        loadModel()
    }

    /// Changement de modèle depuis le chat (sélecteur). Recharge le moteur.
    func switchModel(_ choice: ModelChoice) {
        guard choice != selectedModel, !isGenerating else { return }
        selectedModel = choice
        Preferences.modelVariantRaw = choice.model.rawValue
        rebuildEngine()
        loadModel()
    }

    private func restoreConversations() async {
        conversations = await store.listSummaries()
        if let lastId = Preferences.lastActiveConversationId,
           let conv = await store.load(lastId) {
            currentConversationId = conv.id
            messages = conv.messages.map { ChatMessage(stored: $0) }
        }
    }

    // MARK: - Envoi / génération

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingImagePath != nil || pendingAudioPath != nil, !isGenerating else { return }

        let img = pendingImagePath
        let audioPath = pendingAudioPath
        let audioLabel = pendingAudioLabel

        messages.append(ChatMessage(role: .user, text: text, imagePath: img, audioLabel: audioLabel))
        inputText = ""
        pendingImagePath = nil
        pendingAudioPath = nil
        pendingAudioLabel = nil
        statusMessage = nil

        let titleSeed = !text.isEmpty ? text : (img != nil ? "Image" : "Message vocal")
        ensureConversation(titleSeed: titleSeed)
        persistCurrent()   // sauvegarde le tour utilisateur tout de suite (anti perte si crash/arrêt)

        generateAssistant(promptText: text, imagePath: img, audioPath: audioPath)
    }

    /// Régénère la dernière réponse de l'assistant à partir du dernier message utilisateur.
    func regenerate() {
        guard !isGenerating, let lastUser = messages.last(where: { $0.role == .user }) else { return }
        if let idx = messages.lastIndex(where: { $0.role == .assistant }) {
            messages.remove(at: idx)
        }
        engine.resetConversation()   // repart d'un contexte propre (approximation)
        generateAssistant(promptText: lastUser.text, imagePath: lastUser.imagePath, audioPath: nil)
    }

    /// Démarre une réponse de l'assistant (utilisé par l'envoi et la régénération).
    private func generateAssistant(promptText: String, imagePath: String?, audioPath: String?) {
        let convId = currentConversationId
        let assistant = ChatMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(assistant)
        let assistantId = assistant.id
        isGenerating = true
        liveTokensPerSec = nil

        let stream: AsyncThrowingStream<String, Error> = (imagePath != nil || audioPath != nil)
            ? engine.streamMultimodal(prompt: promptText, imagePath: imagePath, audioPath: audioPath)
            : engine.streamText(prompt: promptText)

        let start = Date()
        generationTask = Task { @MainActor [weak self] in
            var receivedAny = false
            var count = 0
            do {
                for try await token in stream {
                    if Task.isCancelled { break }
                    receivedAny = true
                    count += 1
                    self?.appendToken(token, to: assistantId)
                    let dt = Date().timeIntervalSince(start)
                    if dt > 0.3 { self?.liveTokensPerSec = Double(count) / dt }
                }
            } catch {
                if !Task.isCancelled {
                    self?.statusMessage = "Erreur de génération : \(error.localizedDescription)"
                }
            }
            self?.finishGeneration(assistantId: assistantId, conversationId: convId, receivedAny: receivedAny)
        }
    }

    func useSuggestion(_ text: String) {
        inputText = text
    }

    /// Partage le texte d'un message via la feuille de partage macOS.
    func share(_ text: String) {
        let picker = NSSharingServicePicker(items: [text])
        if let window = NSApp.keyWindow, let view = window.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    private func appendToken(_ token: String, to id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text += token
    }

    private func finishGeneration(assistantId: UUID, conversationId: String?, receivedAny: Bool) {
        // Tour déjà finalisé par un abort (changement de conversation) ou conversation
        // différente entre-temps → ne rien faire pour éviter perte/écrasement.
        guard isGenerating, conversationId == currentConversationId else { return }
        if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
            if !receivedAny && messages[idx].text.isEmpty {
                messages.remove(at: idx)        // stoppé avant le 1er token → on retire la bulle vide
            } else {
                messages[idx].isStreaming = false
            }
        }
        isGenerating = false
        generationTask = nil
        persistCurrent()
    }

    func stopGeneration() {
        generationTask?.cancel()
    }

    /// Annule une génération en cours et finalise + sauvegarde le tour courant
    /// AVANT tout changement de conversation (anti perte / état `isGenerating` figé).
    private func abortGenerationIfNeeded() {
        guard isGenerating else { return }
        generationTask?.cancel()
        generationTask = nil
        if let idx = messages.lastIndex(where: { $0.isStreaming }) {
            if messages[idx].text.isEmpty { messages.remove(at: idx) }
            else { messages[idx].isStreaming = false }
        }
        isGenerating = false
        persistCurrent()
    }

    /// Annule sans persister (utilisé avant suppression de la conversation courante).
    private func cancelGenerationWithoutPersist() {
        guard isGenerating else { return }
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    // MARK: - Conversations

    private func ensureConversation(titleSeed: String) {
        guard currentConversationId == nil else { return }
        let id = UUID().uuidString
        currentConversationId = id
        engine.resetConversation()
        // Résumé provisoire : la conversation apparaît tout de suite dans la barre
        // latérale et son titre (y compris « Image »/« Message vocal ») est conservé
        // par persistCurrent (via existingTitle).
        upsertSummary(ConversationSummary(id: id, title: conversationTitle(seed: titleSeed), updatedAt: nowMillis()))
    }

    private func conversationTitle(seed: String) -> String {
        let trimmed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 40 { return trimmed.isEmpty ? "Nouvelle conversation" : trimmed }
        return String(trimmed.prefix(40)) + "…"
    }

    private func persistCurrent() {
        guard let id = currentConversationId, !messages.isEmpty else { return }
        let now = nowMillis()
        let existingTitle = conversations.first(where: { $0.id == id })?.title
        let title = existingTitle ?? conversationTitle(seed: messages.first(where: { $0.role == .user })?.text ?? "")
        let createdAt = messages.first?.createdAt ?? now
        let conv = StoredConversation(
            id: id, title: title, createdAt: createdAt, updatedAt: now,
            messages: messages.filter { !$0.isStreaming }.map { $0.stored }
        )
        Task { await store.save(conv) }
        Preferences.lastActiveConversationId = id
        upsertSummary(ConversationSummary(id: id, title: title, updatedAt: now))
    }

    private func upsertSummary(_ summary: ConversationSummary) {
        var list = conversations.filter { $0.id != summary.id }
        list.insert(summary, at: 0)
        conversations = list.sorted { $0.updatedAt > $1.updatedAt }
    }

    func newConversation() {
        abortGenerationIfNeeded()
        guard currentConversationId != nil || !messages.isEmpty else { return }
        engine.resetConversation()
        messages = []
        currentConversationId = nil
        Preferences.lastActiveConversationId = nil
        statusMessage = nil
    }

    func openConversation(_ id: String) {
        guard id != currentConversationId else { return }
        abortGenerationIfNeeded()
        Task {
            guard let conv = await store.load(id) else { return }
            engine.resetConversation()
            messages = conv.messages.map { ChatMessage(stored: $0) }
            currentConversationId = id
            Preferences.lastActiveConversationId = id
            statusMessage = nil
        }
    }

    func deleteConversation(_ id: String) {
        if id == currentConversationId { cancelGenerationWithoutPersist() }
        conversations.removeAll { $0.id == id }
        if id == currentConversationId {
            engine.resetConversation()
            messages = []
            currentConversationId = nil
            Preferences.lastActiveConversationId = nil
        }
        // Tombstone côté store → une sauvegarde en vol pour cet id ne ressuscitera pas le fichier.
        Task { await store.delete(id) }
    }

    func renameConversation(_ id: String, to newTitle: String) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Task {
            guard var conv = await store.load(id) else { return }
            conv.title = title
            await store.save(conv)
        }
        if let idx = conversations.firstIndex(where: { $0.id == id }) {
            conversations[idx] = ConversationSummary(id: id, title: title, updatedAt: conversations[idx].updatedAt)
        }
    }

    // MARK: - Saisie

    func updateInput(_ text: String) {
        inputText = String(text.prefix(Self.maxInputChars))
    }

    // MARK: - Image

    func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            setPendingImage(url)
        }
    }

    private var imagesDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GemmaChat/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func setPendingImage(_ url: URL) {
        deletePendingImageCopy()   // évite d'accumuler des copies si on re-sélectionne
        let dest = imagesDir.appendingPathComponent("img_\(nowMillis())_\(url.lastPathComponent)")
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            pendingImagePath = dest.path
        } catch {
            pendingImagePath = url.path   // repli : on garde l'original
        }
    }

    /// Supprime la copie pendante NON ENVOYÉE (n'efface pas les images déjà
    /// rattachées à un message — celles-ci sont référencées par la conversation).
    private func deletePendingImageCopy() {
        guard let path = pendingImagePath, path.hasPrefix(imagesDir.path) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    func clearImage() {
        deletePendingImageCopy()
        pendingImagePath = nil
    }
    func clearAudio() { pendingAudioPath = nil; pendingAudioLabel = nil }

    // MARK: - Audio

    func toggleAudioRecording() {
        if isRecordingAudio {
            stopRecording()
        } else {
            Task { await startRecording() }
        }
    }

    private func startRecording() async {
        guard await recorder.requestPermission() else {
            statusMessage = "Micro inaccessible. Autorisez l'accès au micro dans Réglages Système."
            return
        }
        do {
            _ = try recorder.start()
            isRecordingAudio = true
            recordingElapsedMs = 0
            recordingTimer = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    guard let self, let started = self.recorder.startedAt else { break }
                    self.recordingElapsedMs = Int(Date().timeIntervalSince(started) * 1000)
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func stopRecording() {
        recordingTimer?.cancel()
        recordingTimer = nil
        isRecordingAudio = false
        let seconds = max(1, recordingElapsedMs / 1000)
        if let url = recorder.stop() {
            pendingAudioPath = url.path
            pendingAudioLabel = "Voix (\(seconds)s)"
        } else {
            statusMessage = "Enregistrement trop court ou invalide."
        }
    }

    func cancelAudioRecording() {
        recordingTimer?.cancel()
        recordingTimer = nil
        isRecordingAudio = false
        recorder.cancel()
    }
}
