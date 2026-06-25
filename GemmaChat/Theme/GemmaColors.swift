import SwiftUI

/// Palette portée 1:1 depuis l'app Android (ui/theme/GemmaColors.kt).
/// Les valeurs ARGB d'origine sont conservées à l'identique.
enum GemmaColors {
    // Fonds
    static let background = Color(argb: 0xFF0F1014)
    static let surfaceCard = Color(argb: 0xFF15161D)
    static let surfaceElevated = Color(argb: 0xFF181A22)
    static let surfaceBubble = Color(argb: 0xFF22242F)
    static let surfaceInput = Color(argb: 0xFF23252F)
    static let surfacePill = Color(argb: 0xFF16171E)

    // Texte
    static let textPrimary = Color(argb: 0xFFECEDF1)
    static let textSecondary = Color(argb: 0xFFE7E8EC)
    static let textMuted = Color(argb: 0xFF9CA0AC)
    static let textDim = Color(argb: 0xFF8E929C)
    static let textFaint = Color(argb: 0xFF9094A0)
    static let textIcon = Color(argb: 0xFFC5C8D2)
    static let textStatus = Color(argb: 0xFF9296A0)
    static let textDisclaimer = Color(argb: 0xFF8E929C)

    // Accents
    static let accentPurple = Color(argb: 0xFF6E78FF)
    static let accentPurpleLight = Color(argb: 0xFF8E94FF)
    static let accentPurpleSoft = Color(argb: 0xFF9AA0FF)
    static let accentPurpleMid = Color(argb: 0xFF8A6CF0)
    static let accentPurplePale = Color(argb: 0xFFB6A6FF)
    static let accentPurpleDeep = Color(argb: 0xFF7E84F5)

    static let success = Color(argb: 0xFF34D39A)
    static let successBright = Color(argb: 0xFF5CE0B0)
    static let stopRed = Color(argb: 0xFFFF6B6B)

    static let borderSubtle = Color(argb: 0x14FFFFFF)
    static let borderLight = Color(argb: 0x1FFFFFFF)

    static let iconMuted = Color(argb: 0xFF8B8F9A)
    static let iconAction = Color(argb: 0xFF82868F)
    static let cameraPurple = Color(argb: 0xFFA78BFA)
    static let starGold = Color(argb: 0xFFF3C173)
}

extension Color {
    /// Construit une couleur depuis un entier ARGB 0xAARRGGBB (format Android).
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
