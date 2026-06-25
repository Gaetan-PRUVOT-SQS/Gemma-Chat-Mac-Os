import SwiftUI

/// Écran d'accueil + scan de compatibilité (design slide 1 « Bienvenue dans Gemma »).
struct WelcomeView: View {
    @EnvironmentObject var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            content
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GemmaColors.background)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                GemmaGem(size: 18)
                Text("Gemma — Configuration")
                    .font(.gemmaLabelMedium).foregroundColor(GemmaColors.textMuted)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "lock.fill").font(.system(size: 9))
                Text("100% privé").font(.gemmaLabelMedium)
            }
            .foregroundColor(GemmaColors.success)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var content: some View {
        VStack(spacing: 18) {
            GemmaGem(size: 76)
                .shadow(color: GemmaColors.accentPurple.opacity(0.45), radius: 24)
            Text("Bienvenue dans Gemma")
                .font(.gemmaHeadlineLarge).foregroundColor(GemmaColors.textPrimary)
            Text("Une IA complète qui tourne entièrement sur ton Mac. On a vérifié la mémoire, la puce et l'espace disque — tout est prêt pour fonctionner hors‑ligne.")
                .font(.gemmaBodyLarge).foregroundColor(GemmaColors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            if let scan = vm.scan {
                compatibilityPill(scan)
                HStack(spacing: 12) {
                    ForEach(scan.cards) { card in compatCard(card) }
                }
                .frame(maxWidth: 560)
            }

            VStack(spacing: 14) {
                Text("Tu pourras passer à un autre modèle plus tard.")
                    .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
                chooseModelButton
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 32)
    }

    private func compatibilityPill(_ scan: DeviceScan) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "chart.bar.fill").font(.system(size: 11))
            Text(scan.excellent ? "Compatibilité excellente" : "Compatibilité limitée")
                .font(.gemmaLabelLarge)
        }
        .foregroundColor(scan.excellent ? GemmaColors.success : GemmaColors.starGold)
        .padding(.horizontal, 13).padding(.vertical, 7)
        .background((scan.excellent ? GemmaColors.success : GemmaColors.starGold).opacity(0.12))
        .clipShape(Capsule())
    }

    private func compatCard(_ card: DeviceScan.Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: card.icon)
                    .font(.system(size: 15)).foregroundColor(GemmaColors.accentPurpleSoft)
                Spacer()
                Image(systemName: card.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(card.ok ? GemmaColors.success : GemmaColors.starGold)
            }
            Text(card.value)
                .font(GemmaFont.manrope(15, weight: .bold)).foregroundColor(GemmaColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(card.detail)
                .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GemmaColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(GemmaColors.borderSubtle, lineWidth: 1))
    }

    private var chooseModelButton: some View {
        Menu {
            ForEach(ModelChoice.allCases) { choice in
                Button {
                    vm.chooseModel(choice)
                } label: {
                    let cached = GemmaEngine.isDownloaded(choice.model)
                    Text("\(choice.name) — \(choice.sizeLabel)\(choice.isRecommended ? " · recommandé" : "")\(cached ? " · déjà téléchargé" : "")")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("Choisir mon modèle").font(.gemmaLabelLarge)
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22).padding(.vertical, 12)
            .background(
                LinearGradient(colors: [GemmaColors.accentPurple, GemmaColors.accentPurpleMid],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
