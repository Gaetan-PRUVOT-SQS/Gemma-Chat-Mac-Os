import SwiftUI
import AppKit

/// Rend les écrans clés en PNG (sans fenêtre) pour valider le design. Lancé avec `--shots`.
@MainActor
enum Shots {
    static func run() {
        GemmaFont.registerBundledFonts()
        let vm = ChatViewModel()

        // 1. Accueil + scan
        vm.runScan()
        render(WelcomeView().environmentObject(vm), to: "shot_welcome.png", w: 980, h: 680)

        // 2. Téléchargement
        vm.screen = .download
        vm.isDownloading = true
        vm.downloadFraction = 0.62
        vm.downloadedBytes = 2_230_000_000
        vm.totalBytes = 3_600_000_000
        vm.downloadSpeedBytesPerSec = 28_000_000
        render(DownloadView().environmentObject(vm), to: "shot_download.png", w: 980, h: 680)

        // 3. Chat — accueil vide
        vm.screen = .chat
        vm.messages = []
        render(ChatView().environmentObject(vm), to: "shot_chat_empty.png", w: 980, h: 680)

        // 4. Bulles de messages (hors ScrollView, pour le snapshot) + actions
        let user = ChatMessage(role: .user, text: "Explique la mémoire PLE de Gemma en une phrase.")
        let assistant = ChatMessage(
            role: .assistant,
            text: "La **PLE** (Per‑Layer Embeddings) garde une partie des embeddings hors du chemin critique, couche par couche — d'où un modèle *2 B effectif* qui tient dans ~1,1 Go.\n\n```swift\nlet x = 1\n```")
        let messages = VStack(alignment: .leading, spacing: 16) {
            MessageRow(message: user, isLast: false)
            MessageRow(message: assistant, isLast: true)
        }
        .environmentObject(vm)
        .frame(width: 760)
        .padding(28)
        .background(GemmaColors.background)
        render(messages, to: "shot_messages.png", w: 820, h: 420)

        exit(0)
    }

    private static func render<V: View>(_ view: V, to name: String, w: CGFloat, h: CGFloat) {
        let renderer = ImageRenderer(content: view.frame(width: w, height: h))
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: "/tmp/\(name)"))
        FileHandle.standardError.write("→ /tmp/\(name)\n".data(using: .utf8)!)
    }
}
