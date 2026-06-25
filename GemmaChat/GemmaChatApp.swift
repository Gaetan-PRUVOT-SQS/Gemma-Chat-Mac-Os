import SwiftUI

/// Point d'entrée : route vers le harnais headless `--probe` ou l'app SwiftUI.
@main
enum EntryPoint {
    static func main() {
        if CommandLine.arguments.contains("--probe") {
            Probe.run()   // ne revient pas (exit)
        } else if CommandLine.arguments.contains("--gemshot") {
            GemShot.run() // rend l'écran d'accueil en PNG puis quitte
        } else if CommandLine.arguments.contains("--qa") {
            QAHarness.run() // tests fonctionnels headless puis quitte
        } else if CommandLine.arguments.contains("--shots") {
            Shots.run() // rend les écrans en PNG puis quitte
        } else if CommandLine.arguments.contains("--icon") {
            IconGen.run() // génère l'AppIcon puis quitte
        } else {
            GemmaChatApp.main()
        }
    }
}

struct GemmaChatApp: App {
    @StateObject private var vm = ChatViewModel()

    init() {
        GemmaFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .frame(minWidth: 760, minHeight: 560)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1040, height: 760)
    }
}
