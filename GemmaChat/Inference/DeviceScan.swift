import Foundation

/// Scan de compatibilité de la machine pour l'écran d'accueil (design « Bienvenue »).
/// RAM unifiée, puce + Neural Engine, espace disque libre vs taille requise.
struct DeviceScan {
    struct Card: Identifiable {
        let id = UUID()
        let icon: String
        let value: String
        let detail: String
        let ok: Bool
    }

    let chipName: String
    let totalRAMGB: Int
    let freeDiskGB: Int
    let neuralEngine: Bool
    let cards: [Card]
    /// Compatibilité globale : toutes les cartes au vert.
    var excellent: Bool { cards.allSatisfy { $0.ok } }

    static func run(requiredGB: Double, recommendedRAMGB: Int) -> DeviceScan {
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        let chip = Self.chip()
        let isAppleSilicon = chip.lowercased().contains("apple")
        let freeGB = Self.freeDiskGB()
        let neededGB = Int(ceil(requiredGB))

        let cards: [Card] = [
            Card(icon: "memorychip",
                 value: "\(ramGB) Go",
                 detail: "Mémoire unifiée",
                 ok: ramGB >= recommendedRAMGB),
            Card(icon: "cpu",
                 value: chip,
                 detail: isAppleSilicon ? "Neural Engine dispo" : "Apple Silicon requis",
                 ok: isAppleSilicon),
            Card(icon: "internaldrive",
                 value: "\(freeGB) Go",
                 detail: "Disque libre · besoin \(String(format: "%.1f", requiredGB)) Go",
                 ok: freeGB >= neededGB),
        ]
        return DeviceScan(chipName: chip, totalRAMGB: ramGB, freeDiskGB: freeGB,
                          neuralEngine: isAppleSilicon, cards: cards)
    }

    private static func chip() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var buf = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
            let name = String(cString: buf)
            if !name.isEmpty { return name }
        }
        return "Apple Silicon"
    }

    private static func freeDiskGB() -> Int {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let bytes = values.volumeAvailableCapacityForImportantUsage {
            return Int(bytes / 1_073_741_824)
        }
        return 0
    }
}
