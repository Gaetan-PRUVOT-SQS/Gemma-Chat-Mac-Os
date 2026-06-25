import SwiftUI

struct RootView: View {
    @EnvironmentObject var vm: ChatViewModel

    var body: some View {
        ZStack {
            GemmaColors.background.ignoresSafeArea()
            switch vm.screen {
            case .welcome:
                WelcomeView()
            case .download:
                DownloadView()
            case .chat:
                ChatRootView()
            }
        }
        .task { vm.start() }
        .sheet(isPresented: $vm.showSettings) { SettingsView().environmentObject(vm) }
    }
}

/// Petit logo Gemma réutilisable (pastille violette avec « G »).
struct GemmaLogo: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            Circle().fill(GemmaColors.accentPurple.opacity(0.18))
            Circle().stroke(GemmaColors.accentPurple.opacity(0.5), lineWidth: 1)
            Text("G")
                .font(GemmaFont.manrope(size * 0.5, weight: .heavy))
                .foregroundColor(GemmaColors.accentPurpleSoft)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Gemme violette à 3 facettes — port fidèle du logo Android (ic_gemma_logo.xml,
/// viewBox 24×24). Corps clair, facette haute pâle, facette droite plus foncée.
struct GemmaGem: View {
    var size: CGFloat = 64

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 24.0
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func tri(_ pts: [CGPoint]) -> Path {
                var path = Path()
                path.move(to: pts[0])
                for pt in pts.dropFirst() { path.addLine(to: pt) }
                path.closeSubpath()
                return path
            }
            // Corps complet (losange)
            ctx.fill(tri([p(12, 2.4), p(5.8, 8), p(12, 21.6), p(18.2, 8)]),
                     with: .color(GemmaColors.accentPurpleLight))
            // Facette haute (table)
            ctx.fill(tri([p(12, 2.4), p(5.8, 8), p(18.2, 8)]),
                     with: .color(GemmaColors.accentPurplePale))
            // Facette droite (ombrage 3D)
            ctx.fill(tri([p(12, 2.4), p(12, 21.6), p(18.2, 8)]),
                     with: .color(GemmaColors.accentPurpleDeep))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Formate des octets en Mo pour l'écran de chargement.
func formatMB(_ bytes: Int64) -> String {
    String(format: "%.0f", Double(bytes) / 1_000_000)
}
