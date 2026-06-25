import SwiftUI

/// Sélecteur de modèle dans l'en-tête du chat (design slide 5).
/// Bouton « Gemma 4 E2B ▾ » → popover « MODÈLE INSTALLÉ » avec specs + Activer + accélérateur.
struct ModelSwitcher: View {
    @EnvironmentObject var vm: ChatViewModel
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                GemmaGem(size: 16)
                Text(vm.modelDisplayName).font(.gemmaLabelLarge).foregroundColor(GemmaColors.textPrimary)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    .foregroundColor(GemmaColors.textMuted)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(GemmaColors.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            popoverContent
                .frame(width: 290)
                .background(GemmaColors.surfaceElevated)
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MODÈLE INSTALLÉ")
                .font(.gemmaLabelSmall).foregroundColor(GemmaColors.textDim).tracking(0.5)
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 4)

            ForEach(ModelChoice.allCases) { choice in
                modelRow(choice)
            }

            Divider().overlay(GemmaColors.borderSubtle).padding(.vertical, 4)

            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundColor(GemmaColors.accentPurpleSoft)
                Text("Accélérateur").font(.gemmaBodyMedium).foregroundColor(GemmaColors.textSecondary)
                Spacer()
                Text(vm.accelerator).font(.gemmaLabelMedium).foregroundColor(GemmaColors.textMuted)
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
    }

    private func modelRow(_ choice: ModelChoice) -> some View {
        let isCurrent = choice == vm.selectedModel
        return Button {
            if !isCurrent { vm.switchModel(choice); open = false }
        } label: {
            HStack(spacing: 10) {
                GemmaGem(size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(choice.name).font(.gemmaBodyLarge).foregroundColor(GemmaColors.textPrimary)
                        if let q = choice.qualityLabel {
                            Text(q).font(.gemmaLabelSmall).foregroundColor(GemmaColors.starGold)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(GemmaColors.starGold.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                    Text(choice.pickerSubtitle).font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                        .foregroundColor(GemmaColors.accentPurple)
                } else {
                    Text("Activer").font(.gemmaLabelMedium).foregroundColor(GemmaColors.accentPurpleSoft)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(GemmaColors.accentPurple.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isCurrent ? GemmaColors.surfaceBubble : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
