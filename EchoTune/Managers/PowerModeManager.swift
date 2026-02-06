//
//  PowerModeManager.swift
//  EchoTune
//
//  Phase 6B: Power Mode Manager
//  Detects context and automatically applies appropriate Power Mode
//

import Foundation
import AppKit
import Combine

class PowerModeManager: ObservableObject {
    static let shared = PowerModeManager()

    @Published var powerModes: [PowerMode] = []
    @Published var currentPowerMode: PowerMode?
    @Published var isEnabled: Bool = true

    private let storageKey = "powerModes"
    private let enabledKey = "powerModesEnabled"

    private var currentAppIdentifier: String?
    private var currentWebsiteURL: String?

    private init() {
        loadPowerModes()
        loadEnabledState()
        print("✅ PowerModeManager initialized with \(powerModes.count) modes")
    }

    // MARK: - Power Mode Management

    func addPowerMode(_ mode: PowerMode) {
        powerModes.append(mode)
        savePowerModes()
        print("➕ Added Power Mode: \(mode.name)")
    }

    func updatePowerMode(_ mode: PowerMode) {
        if let index = powerModes.firstIndex(where: { $0.id == mode.id }) {
            var updatedMode = mode
            updatedMode.dateModified = Date()
            powerModes[index] = updatedMode
            savePowerModes()
            print("✏️ Updated Power Mode: \(mode.name)")
        }
    }

    func deletePowerMode(_ mode: PowerMode) {
        powerModes.removeAll { $0.id == mode.id }
        savePowerModes()
        print("🗑️ Deleted Power Mode: \(mode.name)")
    }

    func resetToDefaults() {
        powerModes = PowerMode.defaultModes
        savePowerModes()
        print("🔄 Reset to default Power Modes")
    }

    // MARK: - Context Detection

    /// Detect current context and apply appropriate Power Mode
    func detectAndApplyPowerMode() {
        guard isEnabled else {
            print("⚠️ Power Modes disabled, using global settings")
            currentPowerMode = nil
            return
        }

        // Get current app
        currentAppIdentifier = getFrontmostAppIdentifier()

        // Get current website (if browser)
        if let appId = currentAppIdentifier, isBrowser(appId) {
            currentWebsiteURL = BrowserContextDetector.shared.detectContext()?.url
        } else {
            currentWebsiteURL = nil
        }

        print("🔍 Detecting Power Mode...")
        print("   App: \(currentAppIdentifier ?? "unknown")")
        print("   URL: \(currentWebsiteURL ?? "N/A")")

        // Find matching Power Mode
        let matchingMode = findMatchingPowerMode()

        if let mode = matchingMode {
            applyPowerMode(mode)
        } else {
            print("   No matching Power Mode found, using global settings")
            currentPowerMode = nil
        }
    }

    private func findMatchingPowerMode() -> PowerMode? {
        // Find all matching modes
        let matches = powerModes.filter { mode in
            mode.matches(appIdentifier: currentAppIdentifier, websiteURL: currentWebsiteURL)
        }

        // Sort by priority (highest first), then by use count as tiebreaker
        let sortedMatches = matches.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.useCount > rhs.useCount
        }

        return sortedMatches.first
    }

    /// Update priority for a power mode
    func updatePriority(for modeId: UUID, priority: Int) {
        if let index = powerModes.firstIndex(where: { $0.id == modeId }) {
            powerModes[index].priority = max(0, min(100, priority)) // Clamp 0-100
            powerModes[index].dateModified = Date()
            savePowerModes()
            print("✏️ Updated priority for \(powerModes[index].name) to \(priority)")
        }
    }

    /// Reorder power modes by priority
    func reorderByPriority() {
        powerModes.sort { $0.priority > $1.priority }
        savePowerModes()
    }

    private func applyPowerMode(_ mode: PowerMode) {
        guard mode.id != currentPowerMode?.id else {
            print("   ✅ Already using: \(mode.emoji) \(mode.name)")
            return
        }

        print("   🎯 Applying Power Mode: \(mode.emoji) \(mode.name)")

        currentPowerMode = mode

        // Increment use count
        if let index = powerModes.firstIndex(where: { $0.id == mode.id }) {
            powerModes[index].incrementUseCount()
            savePowerModes()
        }

        // Apply settings to AppSettings
        applySettingsFromPowerMode(mode)

        // Post notification for UI updates
        NotificationCenter.default.post(
            name: NSNotification.Name("PowerModeChanged"),
            object: mode
        )
    }

    private func applySettingsFromPowerMode(_ mode: PowerMode) {
        let settings = AppSettings.shared

        print("   ⚙️ Applying Power Mode settings:")

        // AI Enhancement
        if mode.aiEnhancementEnabled {
            settings.aiEnhancementEnabled = true
            if let model = mode.enhancementModel {
                settings.selectedEnhancementModel = model
                print("      AI Enhancement: ✅ (\(model))")
            }
            if let prompt = mode.customEnhancementPrompt {
                settings.customEnhancementPrompt = prompt
            }
        } else {
            settings.aiEnhancementEnabled = false
            print("      AI Enhancement: ❌")
        }

        // Auto-Send
        settings.autoSendEnabled = mode.autoSendEnabled
        print("      Auto-Send: \(mode.autoSendEnabled ? "✅" : "❌")")

        // Language
        if let language = mode.preferredLanguage {
            settings.preferredLanguage = language
            print("      Language: \(language)")
        }

        // Apply model selection (Whisper vs Cloud)
        if let cloudModelId = mode.cloudModelId, !cloudModelId.isEmpty {
            // Use cloud model
            settings.defaultTranscriptionModel = cloudModelId
            print("      Model: Cloud (\(cloudModelId))")
        } else if mode.useWhisper, let whisperSize = mode.whisperModelSize {
            // Use local Whisper model
            settings.defaultTranscriptionModel = "whisper-\(whisperSize)"
            print("      Model: Whisper (\(whisperSize))")
        }
    }

    // MARK: - Helper Methods

    private func getFrontmostAppIdentifier() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return app.bundleIdentifier
    }

    private func isBrowser(_ bundleIdentifier: String) -> Bool {
        let browsers: Set<String> = [
            "com.google.Chrome",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser",  // Arc
            "com.brave.Browser",
            "com.operasoftware.Opera",
            "com.vivaldi.Vivaldi"
        ]
        return browsers.contains(bundleIdentifier)
    }

    // MARK: - Persistence

    private func savePowerModes() {
        if let encoded = try? JSONEncoder().encode(powerModes) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadPowerModes() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PowerMode].self, from: data) {
            powerModes = decoded
            print("📂 Loaded \(powerModes.count) Power Modes from storage")
        } else {
            // First launch - use defaults
            powerModes = PowerMode.defaultModes
            savePowerModes()
            print("📂 Initialized with default Power Modes")
        }
    }

    private func loadEnabledState() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        } else {
            isEnabled = true // Default: enabled
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)

        if enabled {
            print("✅ Power Modes enabled")
            detectAndApplyPowerMode()
        } else {
            print("❌ Power Modes disabled")
            currentPowerMode = nil
        }
    }

    // MARK: - Statistics

    func getMostUsedPowerModes(limit: Int = 5) -> [PowerMode] {
        return powerModes
            .sorted { $0.useCount > $1.useCount }
            .prefix(limit)
            .map { $0 }
    }

    func getTotalUseCount() -> Int {
        return powerModes.reduce(0) { $0 + $1.useCount }
    }
}
