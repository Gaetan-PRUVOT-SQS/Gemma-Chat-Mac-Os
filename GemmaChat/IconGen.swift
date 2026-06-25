import SwiftUI
import AppKit

/// Génère l'AppIcon (gemme violette sur fond sombre arrondi) à toutes les tailles
/// macOS, dans GemmaChat/Assets.xcassets/AppIcon.appiconset/. Lancé avec `--icon`.
@MainActor
enum IconGen {
    static func run() {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop/GemmaChat-macOS/GemmaChat/Assets.xcassets/AppIcon.appiconset")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        for s in sizes {
            guard let png = renderPNG(size: CGFloat(s)) else { continue }
            try? png.write(to: dir.appendingPathComponent("icon_\(s).png"))
        }
        try? contentsJSON.data(using: .utf8)?.write(to: dir.appendingPathComponent("Contents.json"))

        // Contents.json racine du catalogue.
        let assets = dir.deletingLastPathComponent()
        try? "{\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
            .data(using: .utf8)?.write(to: assets.appendingPathComponent("Contents.json"))

        FileHandle.standardError.write("AppIcon généré → \(dir.path)\n".data(using: .utf8)!)
        exit(0)
    }

    private static func renderPNG(size: CGFloat) -> Data? {
        let renderer = ImageRenderer(content: AppIconView(size: size))
        renderer.scale = 1
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        rep.size = NSSize(width: size, height: size)
        return rep.representation(using: .png, properties: [:])
    }

    private static let contentsJSON = """
    {
      "images" : [
        { "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "16x16", "filename" : "icon_32.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "32x32", "filename" : "icon_32.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "32x32", "filename" : "icon_64.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_256.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_512.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_1024.png" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
}

/// L'icône : fond sombre arrondi (style macOS) + halo violet + gemme centrée.
struct AppIconView: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(argb: 0xFF20212E), Color(argb: 0xFF0C0D12)],
                    startPoint: .top, endPoint: .bottom))
            Circle()
                .fill(RadialGradient(
                    colors: [GemmaColors.accentPurple.opacity(0.55), .clear],
                    center: .center, startRadius: 0, endRadius: size * 0.42))
                .frame(width: size * 0.9, height: size * 0.9)
                .offset(y: -size * 0.01)
            GemmaGem(size: size * 0.54)
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
    }
}
