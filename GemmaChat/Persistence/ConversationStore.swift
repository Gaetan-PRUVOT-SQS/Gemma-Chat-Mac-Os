import Foundation

/// Persistance des conversations en JSON (1 fichier par conversation), hors thread UI.
/// Équivalent de data/ConversationStore.kt. Stocke dans
/// ~/Library/Application Support/GemmaChat/conversations/<id>.json
actor ConversationStore {
    static let shared = ConversationStore()

    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
    private let decoder = JSONDecoder()

    /// Conversations supprimées pendant la session : une sauvegarde en vol (Task
    /// fire-and-forget) ne doit pas recréer le fichier après un delete.
    private var deletedIds: Set<String> = []

    private var directory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GemmaChat", isDirectory: true)
            .appendingPathComponent("conversations", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func fileURL(_ id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    /// Résumés (sans les messages), triés par date de mise à jour décroissante.
    func listSummaries() -> [ConversationSummary] {
        guard let files = try? fm.contentsOfDirectory(at: directory,
                                                      includingPropertiesForKeys: nil) else { return [] }
        var summaries: [ConversationSummary] = []
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let conv = try? decoder.decode(StoredConversation.self, from: data) else { continue }
            summaries.append(ConversationSummary(id: conv.id, title: conv.title, updatedAt: conv.updatedAt))
        }
        return summaries.sorted { $0.updatedAt > $1.updatedAt }
    }

    func load(_ id: String) -> StoredConversation? {
        guard let data = try? Data(contentsOf: fileURL(id)) else { return nil }
        return try? decoder.decode(StoredConversation.self, from: data)
    }

    func save(_ conversation: StoredConversation) {
        guard !deletedIds.contains(conversation.id) else { return }
        guard let data = try? encoder.encode(conversation) else { return }
        try? data.write(to: fileURL(conversation.id), options: .atomic)
    }

    func delete(_ id: String) {
        deletedIds.insert(id)
        try? fm.removeItem(at: fileURL(id))
    }
}

/// Résumé léger pour le tiroir des conversations.
struct ConversationSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let updatedAt: Int
}
