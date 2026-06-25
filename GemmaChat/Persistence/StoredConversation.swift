import Foundation

/// Modèles sérialisés — schéma JSON identique à l'app Android
/// (data/StoredConversation.kt) pour rester compatible.
struct StoredMessage: Codable, Equatable {
    var role: String          // "user" | "model"
    var text: String
    var imageUri: String?
    var audioLabel: String?
    var createdAt: Int

    init(role: String, text: String, imageUri: String? = nil,
         audioLabel: String? = nil, createdAt: Int = 0) {
        self.role = role
        self.text = text
        self.imageUri = imageUri
        self.audioLabel = audioLabel
        self.createdAt = createdAt
    }
}

struct StoredConversation: Codable, Equatable {
    var id: String
    var title: String
    var createdAt: Int
    var updatedAt: Int
    var messages: [StoredMessage]

    init(id: String, title: String, createdAt: Int, updatedAt: Int,
         messages: [StoredMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

/// Horodatage en millisecondes depuis l'epoch (équivalent System.currentTimeMillis()).
func nowMillis() -> Int { Int(Date().timeIntervalSince1970 * 1000) }
