import Foundation
import AVFoundation

/// Enregistre en **WAV PCM 16 bits, 16 kHz, mono** (équivalent AudioRecorder.kt).
///
/// Le préprocesseur audio Gemma lit via `AVAudioFile` et resample en 16 kHz mono ;
/// un WAV PCM linéaire est le format le plus sûr. On passe par `AVAudioRecorder`
/// configuré en LinearPCM, qui écrit un conteneur WAV valide.
@MainActor
final class WavRecorder {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?
    private(set) var startedAt: Date?

    var isRecording: Bool { recorder?.isRecording ?? false }

    /// Demande l'autorisation micro (déclenche le prompt TCC au 1er appel).
    func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    private var recordingsDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GemmaChat/recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    @discardableResult
    func start() throws -> URL {
        cancel()
        // Une seule prise à la fois : on nettoie les anciennes.
        if let files = try? FileManager.default.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil) {
            for f in files { try? FileManager.default.removeItem(at: f) }
        }
        let url = recordingsDir.appendingPathComponent("voice_\(nowMillis()).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let rec = try AVAudioRecorder(url: url, settings: settings)
        guard rec.record() else { throw WavRecorderError.failedToStart }
        recorder = rec
        currentURL = url
        startedAt = Date()
        return url
    }

    /// Arrête et renvoie le fichier si l'enregistrement est exploitable (≥ ~1 s).
    func stop() -> URL? {
        let url = currentURL
        recorder?.stop()
        recorder = nil
        startedAt = nil
        currentURL = nil
        guard let url,
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 44 + 32_000 else {  // en-tête + ~1 s de PCM 16 kHz/16-bit mono (32 000 o/s)
            if let url { try? FileManager.default.removeItem(at: url) }   // nettoie le rebut
            return nil
        }
        return url
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let url = currentURL { try? FileManager.default.removeItem(at: url) }
        currentURL = nil
        startedAt = nil
    }
}

enum WavRecorderError: LocalizedError {
    case failedToStart
    var errorDescription: String? {
        switch self {
        case .failedToStart: return "Micro inaccessible ou enregistrement impossible."
        }
    }
}
