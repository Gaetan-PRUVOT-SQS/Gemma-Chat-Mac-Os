import SwiftUI
import CoreText

/// Familles de police bundlées (variables TTF, OFL), portées depuis l'Android.
/// 100 % local : aucune dépendance à des Google Fonts téléchargeables.
enum GemmaFont {
    static let manrope = "Manrope"
    static let mono = "JetBrains Mono"

    /// Enregistre les polices embarquées dans le bundle au démarrage.
    /// Appelé une seule fois depuis l'App.
    static func registerBundledFonts() {
        for name in ["Manrope", "JetBrainsMono"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func manrope(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(manrope, size: size).weight(weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(mono, size: size).weight(weight)
    }
}

/// Styles de texte équivalents à GemmaTypography (Type.kt). Tailles en points.
extension Font {
    static let gemmaHeadlineLarge = GemmaFont.manrope(24, weight: .heavy)
    static let gemmaHeadlineMedium = GemmaFont.manrope(20, weight: .bold)
    static let gemmaTitleMedium = GemmaFont.manrope(14, weight: .bold)
    static let gemmaTitleSmall = GemmaFont.manrope(12, weight: .semibold)
    static let gemmaBodyLarge = GemmaFont.manrope(15, weight: .regular)
    static let gemmaBodyMedium = GemmaFont.manrope(14, weight: .medium)
    static let gemmaBodySmall = GemmaFont.manrope(11, weight: .medium)
    static let gemmaLabelLarge = GemmaFont.manrope(12, weight: .semibold)
    static let gemmaLabelMedium = GemmaFont.manrope(11, weight: .semibold)
    static let gemmaLabelSmall = GemmaFont.manrope(11, weight: .medium)
}
