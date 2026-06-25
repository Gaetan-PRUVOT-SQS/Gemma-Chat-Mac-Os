import Foundation
import AppKit

/// Harnais de validation headless (hors UI). Lancé avec l'argument `--probe`.
/// Exerce directement GemmaEngine : chargement (download), génération texte,
/// puis multimodal image et audio. Écrit sur stdout et quitte.
@MainActor
enum Probe {
    static func run() {
        Task { @MainActor in
            let ok = await execute()
            exit(ok ? 0 : 1)   // code de sortie exploitable en CI
        }
        RunLoop.main.run()   // pompe la main queue → laisse tourner les tâches @MainActor
    }

    @discardableResult
    private static func execute() async -> Bool {
        let engine = GemmaEngine(model: .e4b4bit)
        log("Modèle : \(engine.model.displayName) — chargement / téléchargement…")
        do {
            var lastPct = -1
            try await engine.load { fraction, done, total in
                let pct = Int(fraction * 100)
                if pct != lastPct && total > 0 {
                    FileHandle.standardError.write("\rDL \(pct)% (\(done / 1_000_000)/\(total / 1_000_000) Mo)   ".data(using: .utf8)!)
                }
            }
            log("\n✅ Modèle chargé.")

            // 1. Texte
            log("\n=== TEXTE ===")
            try await streamPrint(engine.streamText(prompt: "Explique la photosynthèse en exactement trois phrases."))

            // 2. Image (on génère une image avec du texte → test de lecture visuelle)
            if engine.supportsImage, let imagePath = makeTestImage() {
                log("\n\n=== IMAGE (\(imagePath)) ===")
                try await streamPrint(engine.streamMultimodal(
                    prompt: "Quel texte est écrit dans cette image ? Réponds brièvement.",
                    imagePath: imagePath, audioPath: nil))
            }

            // 3. Audio (sinus 440 Hz 2 s → valide le pipeline audio de bout en bout)
            if engine.supportsAudio, let audioPath = makeTestWav() {
                log("\n\n=== AUDIO (\(audioPath)) ===")
                try await streamPrint(engine.streamMultimodal(
                    prompt: "Décris ce que tu entends dans cet audio en une phrase.",
                    imagePath: nil, audioPath: audioPath))
            }

            log("\n\n✅ PROBE TERMINÉ.")
            return true
        } catch {
            log("\n❌ PROBE ERROR: \(error)")
            return false
        }
    }

    private static func streamPrint(_ stream: AsyncThrowingStream<String, Error>) async throws {
        var count = 0
        let start = Date()
        for try await token in stream {
            FileHandle.standardOutput.write(token.data(using: .utf8) ?? Data())
            count += token.count
        }
        let dt = Date().timeIntervalSince(start)
        log("\n[\(count) caractères en \(String(format: "%.1f", dt)) s]")
    }

    private static func log(_ s: String) {
        FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
    }

    // MARK: - Médias de test

    private static func tmp(_ name: String) -> String {
        NSTemporaryDirectory() + name
    }

    /// Image 320×160 noire avec le texte « GEMMA 42 » en blanc.
    private static func makeTestImage() -> String? {
        let size = NSSize(width: 320, height: 160)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 56),
            .foregroundColor: NSColor.white,
        ]
        let text = "GEMMA 42" as NSString
        let ts = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2), withAttributes: attrs)
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let path = tmp("probe_image.png")
        try? png.write(to: URL(fileURLWithPath: path))
        return path
    }

    /// WAV PCM 16 kHz mono, sinus 440 Hz, 2 s.
    private static func makeTestWav() -> String? {
        let sampleRate = 16_000
        let seconds = 2
        let n = sampleRate * seconds
        var samples = [Int16](repeating: 0, count: n)
        for i in 0..<n {
            let v = sin(2.0 * Double.pi * 440.0 * Double(i) / Double(sampleRate))
            samples[i] = Int16(v * 12_000)
        }
        var data = Data()
        func le32(_ v: Int) { var x = UInt32(truncatingIfNeeded: v).littleEndian; data.append(Data(bytes: &x, count: 4)) }
        func le16(_ v: Int) { var x = UInt16(truncatingIfNeeded: v).littleEndian; data.append(Data(bytes: &x, count: 2)) }
        let dataLen = n * 2
        data.append("RIFF".data(using: .ascii)!); le32(dataLen + 36); data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!); le32(16); le16(1); le16(1)
        le32(sampleRate); le32(sampleRate * 2); le16(2); le16(16)
        data.append("data".data(using: .ascii)!); le32(dataLen)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        let path = tmp("probe_audio.wav")
        try? data.write(to: URL(fileURLWithPath: path))
        return path
    }
}
