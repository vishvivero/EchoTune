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
            return "tiny.en" // Tiny models for low-end
        case .medium:
            return "base.en" // Base models for medium-tier
        case .high:
            return "small.en" // Small or higher for high-end
        }
    }
}

class SystemSpecsAnalyzer {
    static let shared = SystemSpecsAnalyzer()

    private init() {}

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
        return availableModels.first(where: { $0.id == recommendedID })
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
        let chipType = specs.isAppleSilicon ? "Apple Silicon" : "Intel"

        switch specs.performanceTier {
        case .veryLow:
            return "Based on your system (\(ramGB)GB RAM, \(chipType)), we recommend using the built-in Apple Speech for optimal performance."
        case .low:
            return "Based on your system (\(ramGB)GB RAM, \(chipType)), we recommend the Tiny model for the best balance of speed and quality."
        case .medium:
            return "Based on your system (\(ramGB)GB RAM, \(chipType)), we recommend the Base model for excellent accuracy with good performance."
        case .high:
            return "Based on your system (\(ramGB)GB RAM, \(chipType)), your Mac can handle the Small or Medium models for superior accuracy."
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
