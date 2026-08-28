//
//  SystemSpecsAnalyzer.swift
//  EchoTune
//
//  System specifications analyzer for recommending optimal AI models
//

import Foundation
import AppKit

struct SystemSpecs {
    let totalRAM: UInt64 // in bytes
    let processorCount: Int
    let processorName: String
    let isAppleSilicon: Bool
    let macOSVersion: String

    var totalRAMInGB: Double {
        Double(totalRAM) / (1024 * 1024 * 1024)
    }

    var performanceTier: PerformanceTier {
        // Determine performance tier based on RAM and processor
        if isAppleSilicon {
            // Apple Silicon Macs
            if totalRAMInGB >= 16 && processorCount >= 8 {
                return .high // M1 Pro/Max/Ultra, M2 Pro/Max, M3 Pro/Max with 16GB+
            } else if totalRAMInGB >= 8 {
                return .medium // M1/M2/M3 base with 8GB+
            } else {
                return .low
            }
        } else {
            // Intel Macs
            if totalRAMInGB >= 16 && processorCount >= 8 {
                return .medium // High-end Intel Macs
            } else if totalRAMInGB >= 8 {
                return .low
            } else {
                return .veryLow
            }
        }
    }
}

enum PerformanceTier {
    case veryLow
    case low
    case medium
    case high

    var description: String {
        switch self {
        case .veryLow: return "Entry-level"
        case .low: return "Standard"
        case .medium: return "Good"
        case .high: return "Excellent"
        }
    }

    var recommendedModelID: String {
        switch self {
        case .veryLow:
            return "apple-speech" // Built-in only for very low-end
        case .low:
            return "openai_whisper-base" // Base model for low-end systems
        case .medium:
            return "distil-whisper_distil-large-v3" // Best speed+accuracy on most Macs
        case .high:
            return "openai_whisper-large-v3-v20240930_turbo" // Slim flagship for M2+ 16GB
        }
    }
}

class SystemSpecsAnalyzer {
    static let shared = SystemSpecsAnalyzer()

    private init() {}

    // Device identifier from sysctl
    var deviceIdentifier: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    // Check if M1 (first gen Apple Silicon)
    var isM1: Bool {
        // M1 devices are Mac13,x (and legacy Mac12,x and earlier Apple Silicon)
        let identifier = deviceIdentifier
        if identifier.hasPrefix("Mac") {
            // Extract number after "Mac"
            let numberStr = identifier.dropFirst(3)
            if let number = Int(numberStr.components(separatedBy: ",")[0]) {
                return number <= 13  // M1 devices: Mac13; Mac14+ is M2+
            }
        }
        return false
    }

    // Check if M2/M3/M4
    var isM2Plus: Bool {
        let identifier = deviceIdentifier
        if identifier.hasPrefix("Mac") {
            let numberStr = identifier.dropFirst(3)
            if let number = Int(numberStr.components(separatedBy: ",")[0]) {
                return number >= 14  // M2: Mac14, M3: Mac16, M4: Mac17+ (Mac15 = M3 MBP Air? — Mac14+ covers M2 and later)
            }
        }
        return false
    }

    func getSystemSpecs() -> SystemSpecs {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let processorCount = ProcessInfo.processInfo.processorCount
        let processorName = getProcessorName()
        let isAppleSilicon = checkIfAppleSilicon()
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString

        return SystemSpecs(
            totalRAM: totalRAM,
            processorCount: processorCount,
            processorName: processorName,
            isAppleSilicon: isAppleSilicon,
            macOSVersion: macOSVersion
        )
    }

    func getRecommendedModel(from availableModels: [AIModel]) -> AIModel? {
        let specs = getSystemSpecs()
        let recommendedID = specs.performanceTier.recommendedModelID

        // Find the recommended model
        // Device-aware recommendation override
        let finalID: String
        switch chipGeneration {
        case .m1:
            // M1 runs the distilled family comfortably; the full classic turbo is heavy
            if recommendedID == "openai_whisper-large-v3-v20240930_turbo" || recommendedID == "openai_whisper-large-v3-turbo" {
                finalID = "distil-whisper_distil-large-v3"
            } else {
                finalID = recommendedID
            }
        case .intel:
            finalID = "openai_whisper-base"
        default:
            finalID = recommendedID
        }

        return availableModels.first(where: { $0.id == finalID })
    }

    // MARK: - Chip generation + per-model fit

    /// Apple Silicon generation of this Mac (or Intel).
    enum ChipGeneration {
        case intel
        case m1
        case m2
        case m3
        case m4orNewer

        var displayName: String {
            switch self {
            case .intel: return "Intel Mac"
            case .m1: return "M1 Apple Silicon"
            case .m2: return "M2 Apple Silicon"
            case .m3: return "M3 Apple Silicon"
            case .m4orNewer: return "M4 Apple Silicon"
            }
        }
    }

    var chipGeneration: ChipGeneration {
        let identifier = deviceIdentifier
        if identifier.hasPrefix("Mac") {
            let numberStr = identifier.dropFirst(3)
            if let number = Int(numberStr.components(separatedBy: ",")[0]) {
                switch number {
                case ..<13: return .intel
                case 13: return .m1
                case 14...15: return .m2
                case 16: return .m3
                default: return .m4orNewer
                }
            }
        }
        return checkIfAppleSilicon() ? .m4orNewer : .intel
    }

    /// How well a model fits this specific Mac — shown as a quiet badge in
    /// onboarding so users can compare without being overwhelmed.
    enum ChipFit {
        case best
        case good
        case heavy

        var label: String {
            switch self {
            case .best: return "Best fit for this chip"
            case .good: return "Works well on this chip"
            case .heavy: return "Heavy for this chip"
            }
        }
    }

    func fitOf(_ model: AIModel, specs: SystemSpecs = SystemSpecsAnalyzer.shared.getSystemSpecs()) -> ChipFit {
        let chip = chipGeneration
        let ramGB = specs.totalRAMInGB
        let isLowRAM = ramGB < 16

        switch model.id {
        case "apple-speech", "openai_whisper-base":
            return .best
        case "openai_whisper-small", "openai_whisper-small.en":
            return .best // tiny enough for everything
        case "distil-whisper_distil-large-v3", "distil-whisper_distil-large-v3_594MB",
             "distil-whisper_distil-large-v3_turbo", "distil-whisper_distil-large-v3_turbo_600MB":
            switch chip {
            case .intel: return .heavy
            case .m1: return isLowRAM ? .good : .best
            case .m2, .m3, .m4orNewer: return .best
            }
        case "openai_whisper-large-v3-v20240930_turbo", "openai_whisper-large-v3-v20240930_turbo_632MB":
            switch chip {
            case .intel: return .heavy
            case .m1: return .heavy
            case .m2: return isLowRAM ? .good : .best
            case .m3, .m4orNewer: return .best
            }
        case "openai_whisper-large-v3-turbo":
            switch chip {
            case .intel, .m1: return .heavy
            case .m2: return isLowRAM ? .good : .best
            case .m3, .m4orNewer: return .best
            }
        default:
            return .good
        }
    }

    func isRecommendedModel(_ model: AIModel) -> Bool {
        // A model is "recommended" if it matches the recommendation for any performance tier
        let allRecommendedIDs = [
            PerformanceTier.veryLow.recommendedModelID,
            PerformanceTier.low.recommendedModelID,
            PerformanceTier.medium.recommendedModelID,
            PerformanceTier.high.recommendedModelID
        ]
        return allRecommendedIDs.contains(model.id)
    }

    func getRecommendationReason() -> String {
        let specs = getSystemSpecs()
        let ramGB = Int(specs.totalRAMInGB)
        let chip = chipGeneration.displayName

        switch specs.performanceTier {
        case .veryLow:
            return "Based on your system (\(ramGB)GB RAM, \(chip)), we recommend the built-in Apple Speech — zero download, always works."
        case .low:
            return "Based on your system (\(ramGB)GB RAM, \(chip)), we recommend the Base model for a good balance of speed and accuracy."
        case .medium:
            return "Based on your system (\(ramGB)GB RAM, \(chip)), we recommend Distil Large v3 — near-large accuracy with fast, offline speed."
        case .high:
            return "Based on your system (\(ramGB)GB RAM, \(chip)), your Mac can comfortably run Large v3 Turbo — maximum accuracy, still offline and free."
        }
    }

    func getSystemInfoString() -> String {
        let specs = getSystemSpecs()
        var info = ""
        info += "System Information:\n"
        info += "- Processor: \(specs.processorName)\n"
        info += "- Cores: \(specs.processorCount)\n"
        info += "- RAM: \(String(format: "%.1f", specs.totalRAMInGB)) GB\n"
        info += "- Architecture: \(specs.isAppleSilicon ? "Apple Silicon" : "Intel")\n"
        info += "- macOS: \(specs.macOSVersion)\n"
        info += "- Performance Tier: \(specs.performanceTier.description)\n"
        return info
    }

    private func checkIfAppleSilicon() -> Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }

        // Apple Silicon Macs have "arm64" architecture
        return machine?.lowercased().contains("arm") ?? false
    }

    private func getProcessorName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let processorName = String(cString: machine)

        // Clean up the name
        if processorName.isEmpty {
            if checkIfAppleSilicon() {
                return "Apple Silicon"
            } else {
                return "Intel Processor"
            }
        }

        return processorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
