import Foundation
import Gemma4Swift

/// Modèles proposés dans l'UI (accueil + sélecteur). On expose E2B (recommandé,
/// plus léger/rapide) et E4B (qualité+). Tailles RÉELLES des poids MLX 4-bit.
enum ModelChoice: String, CaseIterable, Identifiable {
    case e2b
    case e4b

    var id: String { rawValue }

    var model: Gemma4Pipeline.Model { self == .e2b ? .e2b4bit : .e4b4bit }

    var name: String { self == .e2b ? "Gemma 4 E2B" : "Gemma 4 E4B" }

    var edition: String {
        self == .e2b ? "Édition Edge · 2 Md effectifs · Q4" : "Qualité+ · 4,5 Md effectifs · Q4"
    }

    /// Taille réelle du téléchargement MLX (Go).
    var sizeGB: Double { Double(model.estimatedSizeGB) }

    var sizeLabel: String { String(format: "%.1f Go", sizeGB) }

    var recommendedRAMGB: Int { model.recommendedRAMGB }

    var isRecommended: Bool { self == .e2b }

    var qualityLabel: String? { self == .e4b ? "QUALITÉ+" : nil }

    /// Étiquettes affichées sous le nom du modèle.
    var tags: [String] {
        ["\(sizeLabel)", "128K contexte", "Texte · Vision · Audio"]
    }

    /// Sous-titre court pour le sélecteur (specs).
    var pickerSubtitle: String {
        self == .e2b ? "\(sizeLabel) · équilibré" : "\(sizeLabel) · plus précis"
    }

    static func from(model: Gemma4Pipeline.Model) -> ModelChoice {
        model.family == .e2b ? .e2b : .e4b
    }

    static func from(raw: String?) -> ModelChoice? {
        guard let raw, let m = Gemma4Pipeline.Model(rawValue: raw) else { return nil }
        return from(model: m)
    }
}
