import Foundation

enum MessageRole {
    case user
    case assistant
}

/// Message affiché dans le chat (équivalent ChatMessage Android).
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var role: MessageRole
    var text: String
    var imagePath: String?       // chemin local d'une image jointe
    var audioLabel: String?      // ex. "Voix (5s)"
    var createdAt: Int           // ms depuis l'epoch
    var isStreaming: Bool

    init(id: UUID = UUID(), role: MessageRole, text: String,
         imagePath: String? = nil, audioLabel: String? = nil,
         createdAt: Int = nowMillis(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.imagePath = imagePath
        self.audioLabel = audioLabel
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }

    var timeString: String {
        let date = Date(timeIntervalSince1970: Double(createdAt) / 1000)
        return Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

enum AppScreen {
    case welcome     // accueil + scan de compatibilité
    case download    // téléchargement du modèle
    case chat
}

extension ChatMessage {
    var stored: StoredMessage {
        StoredMessage(
            role: role == .user ? "user" : "model",
            text: text,
            imageUri: imagePath,
            audioLabel: audioLabel,
            createdAt: createdAt
        )
    }

    init(stored: StoredMessage) {
        self.init(
            role: stored.role == "user" ? .user : .assistant,
            text: stored.text,
            imagePath: stored.imageUri,
            audioLabel: stored.audioLabel,
            createdAt: stored.createdAt,
            isStreaming: false
        )
    }
}
