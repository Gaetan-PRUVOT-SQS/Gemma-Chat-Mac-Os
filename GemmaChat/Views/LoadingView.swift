import SwiftUI

/// Écran de téléchargement / chargement du modèle (design slide 2).
struct DownloadView: View {
    @EnvironmentObject var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            if let error = vm.loadError {
                errorState(error)
            } else {
                card
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GemmaColors.background)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            GemmaGem(size: 18)
            Text("Installation de Gemma")
                .font(.gemmaLabelMedium).foregroundColor(GemmaColors.textMuted)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 22) {
            modelHeader
            if vm.isInitializing && !vm.isDownloading {
                initState
            } else {
                progressState
            }
            controls
        }
        .padding(24)
        .frame(maxWidth: 560)
        .background(GemmaColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(GemmaColors.borderSubtle, lineWidth: 1))
        .padding(.horizontal, 28)
    }

    private var modelHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                GemmaGem(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.selectedModel.name)
                        .font(.gemmaHeadlineMedium).foregroundColor(GemmaColors.textPrimary)
                    Text(vm.selectedModel.edition)
                        .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
                }
                Spacer()
                if vm.selectedModel.isRecommended {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 9))
                        Text("Recommandé").font(.gemmaLabelMedium)
                    }
                    .foregroundColor(GemmaColors.success)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(GemmaColors.success.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            HStack(spacing: 8) {
                ForEach(vm.selectedModel.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.gemmaLabelMedium).foregroundColor(GemmaColors.textMuted)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(GemmaColors.surfacePill)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var progressState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(vm.downloadFraction * 100))")
                    .font(GemmaFont.manrope(40, weight: .heavy)).foregroundColor(GemmaColors.textPrimary)
                Text("%").font(.gemmaHeadlineMedium).foregroundColor(GemmaColors.textMuted)
                Spacer()
                Text(vm.isPaused ? "En pause" : "Téléchargement sur Wi‑Fi…")
                    .font(.gemmaBodyMedium).foregroundColor(GemmaColors.textMuted)
            }
            ProgressView(value: vm.downloadFraction)
                .tint(GemmaColors.accentPurple)
            HStack {
                Text("\(formatGB(vm.downloadedBytes)) / \(formatGB(vm.totalBytes)) Go · \(formatMBs(vm.downloadSpeedBytesPerSec))")
                Spacer()
                if let eta = vm.downloadETASeconds { Text("≈ \(formatETA(eta)) restantes") }
            }
            .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)

            infoRow
        }
    }

    private var initState: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small).tint(GemmaColors.accentPurple)
            Text("Chargement du modèle en mémoire…")
                .font(.gemmaBodyLarge).foregroundColor(GemmaColors.textSecondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var infoRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").font(.system(size: 12)).foregroundColor(GemmaColors.textDim)
            Text("Tu peux quitter cette fenêtre. Si la connexion coupe, le téléchargement reprend tout seul là où il s'est arrêté.")
                .font(.gemmaBodySmall).foregroundColor(GemmaColors.textDim)
        }
        .padding(10)
        .background(GemmaColors.surfacePill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var controls: some View {
        if vm.isDownloading || vm.isPaused {
            HStack(spacing: 10) {
                Button(action: vm.isPaused ? vm.resumeDownload : vm.pauseDownload) {
                    HStack(spacing: 6) {
                        Image(systemName: vm.isPaused ? "play.fill" : "pause.fill").font(.system(size: 11))
                        Text(vm.isPaused ? "Reprendre" : "Mettre en pause").font(.gemmaLabelLarge)
                    }
                    .foregroundColor(GemmaColors.textPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(GemmaColors.surfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                Button(action: vm.cancelDownload) {
                    Text("Annuler").font(.gemmaLabelLarge).foregroundColor(GemmaColors.textMuted)
                        .padding(.horizontal, 18).padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30)).foregroundColor(GemmaColors.starGold)
            Text(error).font(.gemmaBodyLarge).foregroundColor(GemmaColors.textSecondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            HStack(spacing: 10) {
                Button(action: vm.retryLoad) {
                    Text("Réessayer").font(.gemmaLabelLarge).foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(GemmaColors.accentPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                Button(action: vm.cancelDownload) {
                    Text("Choisir un autre modèle").font(.gemmaLabelLarge).foregroundColor(GemmaColors.textMuted)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
    }

    // MARK: - Formatage

    private func formatGB(_ bytes: Int64) -> String { String(format: "%.2f", Double(bytes) / 1_000_000_000) }
    private func formatMBs(_ bps: Double) -> String { String(format: "%.0f Mo/s", bps / 1_000_000) }
    private func formatETA(_ s: Int) -> String { s >= 60 ? "\(s / 60) min \(s % 60) s" : "\(s) s" }
}
