import SwiftUI

struct ChatRootView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ConversationSidebar()
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 340)
        } detail: {
            ChatView()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct ConversationSidebar: View {
    @EnvironmentObject var vm: ChatViewModel
    @State private var renamingId: String?
    @State private var renameText = ""
    @State private var deletingId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            newDiscussionButton
            searchField
            conversationList
            Divider().overlay(GemmaColors.borderSubtle)
            bottomStatus
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(GemmaColors.surfaceCard)
        .alert("Renommer la conversation", isPresented: Binding(
            get: { renamingId != nil }, set: { if !$0 { renamingId = nil } }
        )) {
            TextField("Titre", text: $renameText)
            Button("Renommer") {
                if let id = renamingId { vm.renameConversation(id, to: renameText) }
                renamingId = nil
            }
            Button("Annuler", role: .cancel) { renamingId = nil }
        }
        .confirmationDialog(
            deleteMessage,
            isPresented: Binding(get: { deletingId != nil }, set: { if !$0 { deletingId = nil } }),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let id = deletingId { vm.deleteConversation(id) }
                deletingId = nil
            }
            Button("Annuler", role: .cancel) { deletingId = nil }
        }
    }

    private var newDiscussionButton: some View {
        Button(action: vm.newConversation) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Nouvelle discussion").font(.gemmaLabelLarge)
                Spacer()
                Text("⌘N").font(GemmaFont.mono(11)).foregroundColor(GemmaColors.textDim)
            }
            .foregroundColor(GemmaColors.accentPurpleSoft)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(GemmaColors.accentPurple.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(GemmaColors.accentPurple.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(GemmaColors.textDim)
            TextField("Rechercher", text: $vm.searchQuery)
                .textFieldStyle(.plain)
                .font(.gemmaBodyMedium)
                .foregroundColor(GemmaColors.textSecondary)
            Text("⌘K").font(GemmaFont.mono(10)).foregroundColor(GemmaColors.textDim)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(GemmaColors.surfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 12).padding(.bottom, 10)
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if vm.groupedConversations.isEmpty {
                    Text(vm.searchQuery.isEmpty ? "Aucune conversation enregistrée" : "Aucun résultat")
                        .font(.gemmaBodySmall).foregroundColor(GemmaColors.textMuted)
                        .padding(.horizontal, 12).padding(.top, 10)
                }
                ForEach(vm.groupedConversations, id: \.title) { group in
                    Text(group.title.uppercased())
                        .font(.gemmaLabelSmall).foregroundColor(GemmaColors.textDim)
                        .tracking(0.5)
                        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)
                    ForEach(group.items) { conv in row(conv) }
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 10)
        }
    }

    private var bottomStatus: some View {
        HStack(spacing: 8) {
            GemmaGem(size: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(vm.modelDisplayName).font(.gemmaLabelMedium).foregroundColor(GemmaColors.textSecondary)
                HStack(spacing: 4) {
                    Circle().fill(GemmaColors.success).frame(width: 5, height: 5)
                    Text("Hors‑ligne · \(vm.accelerator)").font(.gemmaLabelSmall).foregroundColor(GemmaColors.textDim)
                }
            }
            Spacer()
            Button { vm.showSettings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 14)).foregroundColor(GemmaColors.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Réglages")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var deleteMessage: String {
        let title = vm.conversations.first(where: { $0.id == deletingId })?.title ?? ""
        return "« \(title) » sera définitivement supprimée."
    }

    @ViewBuilder
    private func row(_ conv: ConversationSummary) -> some View {
        let isSelected = conv.id == vm.currentConversationId
        Button {
            vm.openConversation(conv.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 12)).foregroundColor(GemmaColors.textMuted)
                Text(conv.title)
                    .font(isSelected ? GemmaFont.manrope(13, weight: .semibold) : .gemmaBodyMedium)
                    .foregroundColor(isSelected ? GemmaColors.textPrimary : GemmaColors.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(isSelected ? GemmaColors.surfaceBubble : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? GemmaColors.borderLight : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Renommer") { renameText = conv.title; renamingId = conv.id }
            Button("Supprimer", role: .destructive) { deletingId = conv.id }
        }
    }
}
