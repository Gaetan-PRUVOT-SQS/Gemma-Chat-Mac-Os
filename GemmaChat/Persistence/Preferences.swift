import Foundation

/// Préférences persistées (UserDefaults) — équivalent ModelPreferences.kt.
enum Preferences {
    private static let lastConversationKey = "last_conversation_id"
    private static let modelVariantKey = "model_variant"

    static var lastActiveConversationId: String? {
        get { UserDefaults.standard.string(forKey: lastConversationKey) }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: lastConversationKey) }
            else { UserDefaults.standard.removeObject(forKey: lastConversationKey) }
        }
    }

    /// rawValue de Gemma4Pipeline.Model (ex: "mlx-community/gemma-4-e4b-it-4bit").
    static var modelVariantRaw: String? {
        get { UserDefaults.standard.string(forKey: modelVariantKey) }
        set { UserDefaults.standard.set(newValue, forKey: modelVariantKey) }
    }

    private static let temperatureKey = "gen_temperature"
    private static let maxTokensKey = "gen_max_tokens"

    static var temperature: Double {
        get { UserDefaults.standard.object(forKey: temperatureKey) as? Double ?? 0.7 }
        set { UserDefaults.standard.set(newValue, forKey: temperatureKey) }
    }

    static var maxTokens: Int {
        get { let v = UserDefaults.standard.integer(forKey: maxTokensKey); return v == 0 ? 2048 : v }
        set { UserDefaults.standard.set(newValue, forKey: maxTokensKey) }
    }
}
