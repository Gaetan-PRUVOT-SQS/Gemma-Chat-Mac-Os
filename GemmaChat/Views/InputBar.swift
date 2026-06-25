import SwiftUI
import AppKit

struct InputBar: View {
    @EnvironmentObject var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 8) {
            if vm.pendingImagePath != nil || vm.pendingAudioLabel != nil {
                attachmentChips
            }
            if vm.isRecordingAudio {
                recordingRow
            }
            inputRow
            Text("Gemma peut halluciner · Tout reste sur ton Mac")
                .font(.gemmaLabelSmall)
                .foregroundColor(GemmaColors.textDisclaimer)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(GemmaColors.surfaceCard)
    }

    // MARK: - Pièces jointes

    private var attachmentChips: some View {
        HStack(spacing: 8) {
            if vm.pendingImagePath != nil {
                attachmentChip(icon: "photo", text: "Image jointe") { vm.clearImage() }
            }
            if let audio = vm.pendingAudioLabel {
                attachmentChip(icon: "waveform", text: audio) { vm.clearAudio() }
            }
            Spacer()
        }
    }

    private func attachmentChip(icon: String, text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.gemmaLabelMedium)
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retirer la pièce jointe")
        }
        .foregroundColor(GemmaColors.accentPurpleSoft)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(GemmaColors.surfacePill)
        .clipShape(Capsule())
    }

    // MARK: - Enregistrement

    private var recordingRow: some View {
        HStack(spacing: 10) {
            Circle().fill(GemmaColors.starGold).frame(width: 8, height: 8)
            Text("Enregistrement \(vm.recordingElapsedMs / 1000)s")
                .font(.gemmaBodyMedium).foregroundColor(GemmaColors.textSecondary)
            Spacer()
            Button("Annuler") { vm.cancelAudioRecording() }
                .buttonStyle(.plain)
                .font(.gemmaLabelMedium)
                .foregroundColor(GemmaColors.textMuted)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(GemmaColors.surfacePill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Ligne de saisie

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if vm.supportsImage {
                iconButton("photo", label: "Joindre une image",
                           disabled: vm.isGenerating || vm.isRecordingAudio) {
                    vm.pickImage()
                }
            }
            if vm.supportsAudio {
                iconButton(vm.isRecordingAudio ? "stop.circle.fill" : "mic",
                           label: vm.isRecordingAudio ? "Arrêter l'enregistrement" : "Enregistrer un message audio",
                           tint: vm.isRecordingAudio ? GemmaColors.starGold : GemmaColors.textIcon,
                           disabled: vm.isGenerating) {
                    vm.toggleAudioRecording()
                }
            }

            TextField("Écris à Gemma…", text: Binding(
                get: { vm.inputText },
                set: { vm.updateInput($0) }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.gemmaBodyLarge)
            .foregroundColor(GemmaColors.textPrimary)
            .lineLimit(1...5)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(GemmaColors.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onSubmit { vm.sendMessage() }

            sendButton
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        if vm.isGenerating {
            Button(action: vm.stopGeneration) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                    Text("Arrêter").font(.gemmaLabelMedium)
                }
                .foregroundColor(GemmaColors.stopRed)
                .padding(.horizontal, 12).frame(height: 38)
                .background(GemmaColors.stopRed.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(GemmaColors.stopRed.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Arrêter la génération")
        } else {
            Button(action: vm.sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(vm.canSend ? GemmaColors.accentPurple : GemmaColors.surfaceInput)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSend)
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityLabel("Envoyer le message")
        }
    }

    private func iconButton(_ systemName: String,
                            label: String,
                            tint: Color = GemmaColors.textIcon,
                            disabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundColor(disabled ? GemmaColors.textDim : tint)
                .frame(width: 38, height: 38)
                .background(GemmaColors.surfaceInput)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}
