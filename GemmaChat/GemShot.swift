import SwiftUI
import AppKit

/// Rend l'aperçu de l'écran d'accueil (gemme + titre) en PNG, sans fenêtre.
/// Lancé avec `--gemshot`. Sert à valider le rendu de la gemme.
@MainActor
enum GemShot {
    static func run() {
        GemmaFont.registerBundledFonts()
        let preview = ZStack {
            GemmaColors.background
            VStack(spacing: 16) {
                GemmaGem(size: 120)
                Text("GemmaChat")
                    .font(.gemmaHeadlineLarge)
                    .foregroundColor(GemmaColors.textPrimary)
                Text("Un assistant qui tourne entièrement sur ton Mac.")
                    .font(.gemmaBodyLarge)
                    .foregroundColor(GemmaColors.textMuted)
            }
        }
        .frame(width: 420, height: 340)

        let renderer = ImageRenderer(content: preview)
        renderer.scale = 2
        if let nsImage = renderer.nsImage,
           let tiff = nsImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gemshot.png"))
            FileHandle.standardError.write("gemshot écrit → /tmp/gemshot.png\n".data(using: .utf8)!)
        }
        exit(0)
    }
}
