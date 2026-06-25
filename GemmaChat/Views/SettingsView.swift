import SwiftUI

/// Réglages (design slide 6). Contrôles réellement câblés : accélérateur (info),
/// température, tokens max, stockage + vider le cache.
struct SettingsView: View {
    @EnvironmentObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Réglages").font(.gemmaHeadlineMedium).foregroundColor(GemmaColors.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                        .foregroundColor(GemmaColors.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer les réglages")
            }
            .padding(18)

            Divider().overlay(GemmaColors.borderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("Accélération matérielle") {
                        acceleratorRow("GPU Metal", "recommandé", active: true)
                        acceleratorRow("Neural Engine", "expérimental", active: false)
                        acceleratorRow("CPU", "éco. batterie", active: false)
                        Text("Le moteur MLX s'exécute sur le GPU Metal d'Apple Silicon.")
                            .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
                    }

                    section("Génération") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Température").font(.gemmaBodyLarge).foregroundColor(GemmaColors.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f", vm.temperature))
                                    .font(GemmaFont.mono(13)).foregroundColor(GemmaColors.accentPurpleSoft)
                            }
                            Slider(value: $vm.temperature, in: 0...1.5, step: 0.1)
                                .tint(GemmaColors.accentPurple)
                            Text("Plus bas = plus déterministe · plus haut = plus créatif.")
                                .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
                        }
                        Divider().overlay(GemmaColors.borderSubtle)
                        Stepper(value: $vm.maxTokens, in: 256...4096, step: 256) {
                            HStack {
                                Text("Tokens max par réponse").font(.gemmaBodyLarge).foregroundColor(GemmaColors.textSecondary)
                                Spacer()
                                Text("\(vm.maxTokens)").font(GemmaFont.mono(13)).foregroundColor(GemmaColors.accentPurpleSoft)
                            }
                        }
                    }

                    section("Stockage") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.selectedModel.name).font(.gemmaBodyLarge).foregroundColor(GemmaColors.textSecondary)
                                Text("\(vm.selectedModel.sizeLabel) · cache KV en mémoire")
                                    .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
                            }
                            Spacer()
                            Button { vm.clearCache() } label: {
                                Text("Vider le cache").font(.gemmaLabelMedium).foregroundColor(GemmaColors.textIcon)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(GemmaColors.surfaceInput)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 540)
        .background(GemmaColors.background)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.gemmaLabelMedium).foregroundColor(GemmaColors.textDim)
                .tracking(0.5)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GemmaColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func acceleratorRow(_ name: String, _ tag: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .foregroundColor(active ? GemmaColors.accentPurple : GemmaColors.textDim)
            Text(name).font(.gemmaBodyLarge).foregroundColor(active ? GemmaColors.textPrimary : GemmaColors.textMuted)
            Text(tag).font(.gemmaLabelSmall).foregroundColor(GemmaColors.textDim)
            Spacer()
        }
        .opacity(active ? 1 : 0.6)
    }
}
