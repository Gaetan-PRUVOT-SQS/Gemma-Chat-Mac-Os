import SwiftUI

struct ChatView: View {
    @EnvironmentObject var vm: ChatViewModel
    @State private var atBottom = true
    private let bottomAnchor = "bottom-anchor"

    private let suggestions = [
        "Résume ce document en 3 points",
        "Analyse une capture d'écran",
        "Écris un script Swift simple",
        "Explique-moi un concept simplement",
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(GemmaColors.borderSubtle)

            if vm.messages.isEmpty {
                welcome
            } else {
                messagesList
            }

            if let status = vm.statusMessage {
                statusBanner(status)
            }

            perfLine
            InputBar()
        }
        .background(GemmaColors.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 10) {
            ModelSwitcher()
            HStack(spacing: 5) {
                Circle().fill(GemmaColors.success).frame(width: 6, height: 6).accessibilityHidden(true)
                Text("100% local").font(.gemmaLabelMedium).foregroundColor(GemmaColors.success)
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(GemmaColors.success.opacity(0.10))
            .clipShape(Capsule())
            Spacer()
            Button { vm.showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                    .foregroundColor(GemmaColors.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Réglages")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(GemmaColors.surfaceCard)
    }

    // MARK: - Liste des messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(vm.messages) { message in
                        MessageRow(message: message, isLast: message.id == vm.messages.last?.id)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.containerSize.height >= geo.contentSize.height - 48
            } action: { _, nearBottom in
                atBottom = nearBottom
            }
            .onChange(of: vm.messages.count) { _ in
                atBottom = true
                withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
            .onChange(of: vm.messages.last?.text) { _ in
                if atBottom { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
        }
    }

    // MARK: - Accueil (chat vide)

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer().frame(height: 50)
                GemmaGem(size: 60)
                    .shadow(color: GemmaColors.accentPurple.opacity(0.4), radius: 20)
                Text("Salut, moi c'est Gemma.")
                    .font(.gemmaHeadlineLarge).foregroundColor(GemmaColors.textPrimary)
                Text("Je tourne entièrement sur ton Mac. Pose une question, glisse une image\(vm.supportsAudio ? " ou enregistre un audio." : ".")")
                    .font(.gemmaBodyLarge).foregroundColor(GemmaColors.textMuted)
                    .multilineTextAlignment(.center).frame(maxWidth: 460)

                VStack(spacing: 8) {
                    ForEach(Array(stride(from: 0, to: suggestions.count, by: 2)), id: \.self) { i in
                        HStack(spacing: 8) {
                            suggestionChip(suggestions[i])
                            if i + 1 < suggestions.count { suggestionChip(suggestions[i + 1]) }
                        }
                    }
                }
                .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button { vm.useSuggestion(text) } label: {
            Text(text)
                .font(.gemmaBodyMedium).foregroundColor(GemmaColors.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(GemmaColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(GemmaColors.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ligne de performance

    @ViewBuilder
    private var perfLine: some View {
        if vm.isGenerating, let tps = vm.liveTokensPerSec {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill").font(.system(size: 9))
                    Text(String(format: "%.0f tok/s", tps))
                }
                .foregroundColor(GemmaColors.accentPurpleSoft)
                Text("·").foregroundColor(GemmaColors.textDim)
                Text(vm.accelerator).foregroundColor(GemmaColors.textDim)
                Spacer()
            }
            .font(.gemmaLabelMedium)
            .padding(.horizontal, 20).padding(.top, 6)
        }
    }

    private func statusBanner(_ status: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle").foregroundColor(GemmaColors.starGold)
            Text(status).font(.gemmaBodySmall).foregroundColor(GemmaColors.textSecondary)
            Spacer()
            Button { vm.statusMessage = nil } label: {
                Image(systemName: "xmark").font(.system(size: 10)).foregroundColor(GemmaColors.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer le message")
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(GemmaColors.surfacePill)
    }
}
