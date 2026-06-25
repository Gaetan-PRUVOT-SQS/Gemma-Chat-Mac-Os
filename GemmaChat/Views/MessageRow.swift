import SwiftUI
import AppKit

struct MessageRow: View {
    @EnvironmentObject var vm: ChatViewModel
    let message: ChatMessage
    var isLast: Bool = false

    var body: some View {
        if message.role == .user {
            userRow
        } else {
            assistantRow
        }
    }

    // MARK: - Utilisateur

    private var userRow: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 6) {
                if let path = message.imagePath {
                    if let image = NSImage(contentsOfFile: path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 172, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel("Image jointe")
                    } else {
                        chip(icon: "photo", text: "Image indisponible")
                    }
                }
                if let audio = message.audioLabel {
                    chip(icon: "waveform", text: audio)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.gemmaBodyLarge)
                        .foregroundColor(GemmaColors.textPrimary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(GemmaColors.surfaceBubble)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Text(message.timeString)
                    .font(.gemmaLabelSmall)
                    .foregroundColor(GemmaColors.textDim)
            }
        }
    }

    // MARK: - Assistant

    private var assistantRow: some View {
        HStack(alignment: .top, spacing: 10) {
            GemmaGem(size: 22)
            VStack(alignment: .leading, spacing: 6) {
                if message.text.isEmpty && message.isStreaming {
                    TypingIndicator()
                } else {
                    MarkdownView(text: message.text)
                }
                if !message.isStreaming && !message.text.isEmpty {
                    HStack(spacing: 14) {
                        actionButton("doc.on.doc", "Copier") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                        if isLast && !vm.isGenerating {
                            actionButton("arrow.clockwise", "Régénérer") { vm.regenerate() }
                        }
                        actionButton("square.and.arrow.up", "Partager") { vm.share(message.text) }
                        Spacer().frame(width: 2)
                        Text(message.timeString)
                            .font(.gemmaLabelSmall).foregroundColor(GemmaColors.textDim)
                    }
                    .padding(.top, 3)
                }
            }
            Spacer(minLength: 40)
        }
    }

    private func actionButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.gemmaLabelSmall)
            }
            .foregroundColor(GemmaColors.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.gemmaLabelMedium)
        }
        .foregroundColor(GemmaColors.accentPurpleSoft)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(GemmaColors.surfacePill)
        .clipShape(Capsule())
    }
}

/// Trois points animés + « Gemma écrit… ».
struct TypingIndicator: View {
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(GemmaColors.accentPurpleSoft)
                    .frame(width: 6, height: 6)
                    .opacity(0.4 + 0.6 * abs(sin(phase + Double(i) * 0.6)))
            }
            Text("Gemma écrit…")
                .font(.gemmaBodySmall)
                .foregroundColor(GemmaColors.textMuted)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
