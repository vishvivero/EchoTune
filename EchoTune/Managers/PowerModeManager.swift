//
//  PowerModeManager.swift
//  EchoTune
//
//  Phase 6B+: Power Mode Manager with Auto App-Switching
//  Detects context and automatically applies appropriate Power Mode
//  when the user switches applications
//

import Foundation
import AppKit
import Combine

class PowerModeManager: ObservableObject {
    static let shared = PowerModeManager()

    @Published var powerModes: [PowerMode] = []
    @Published var currentPowerMode: PowerMode?
    @Published var isEnabled: Bool = true
    @Published var isAutoSwitchEnabled: Bool = true  // NEW: auto-switch on app change

    private let storageKey = "powerModes"
    private let enabledKey = "powerModesEnabled"
    private let autoSwitchKey = "powerModesAutoSwitch"

    private var currentAppIdentifier: String?
    private var currentWebsiteURL: String?

    // NSWorkspace observer for automatic app-switching
    private var appSwitchObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // Debounce: avoid rapid fire when clicking between apps
    private var appSwitchWorkItem: DispatchWorkItem?

    private init() {
        loadPowerModes()
        loadEnabledState()
        setupAppSwitchMonitoring()
        debugLog("✅ PowerModeManager initialized with \(powerModes.count) modes, auto-switch: \(isAutoSwitchEnabled)")
    }

    deinit {
        stopAppSwitchMonitoring()
    }

    // MARK: - App Switch Monitoring (NEW)

    /// Sets up NSWorkspace observation to detect when the user switches apps
    private func setupAppSwitchMonitoring() {
        // Observe frontmost application changes
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard self.isEnabled && self.isAutoSwitchEnabled else { return }

            // Extract the newly activated app
            guard let userInfo = notification.userInfo,
                  let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else {
                return
            }

            // Don't re-trigger if we're still in the same app
            guard bundleId != self.currentAppIdentifier else { return }

            debugLog("🔀 App switched to: \(app.localizedName ?? bundleId)")

            // Debounce: cancel previous work item and schedule new one
            self.appSwitchWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.detectAndApplyPowerMode()
            }
            self.appSwitchWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }

    private func stopAppSwitchMonitoring() {
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appSwitchObserver = nil
        }
        appSwitchWorkItem?.cancel()
    }

    // MARK: - Power Mode Management

    func addPowerMode(_ mode: PowerMode) {
        powerModes.append(mode)
        savePowerModes()
        debugLog("➕ Added Power Mode: \(mode.name)")
    }

    func updatePowerMode(_ mode: PowerMode) {
        if let index = powerModes.firstIndex(where: { $0.id == mode.id }) {
            var updatedMode = mode
            updatedMode.dateModified = Date()
            powerModes[index] = updatedMode
            savePowerModes()
            debugLog("✏️ Updated Power Mode: \(mode.name)")
        }
    }

    func deletePowerMode(_ mode: PowerMode) {
        powerModes.removeAll { $0.id == mode.id }
        savePowerModes()
        debugLog("🗑️ Deleted Power Mode: \(mode.name)")
    }

    func resetToDefaults() {
        powerModes = PowerMode.defaultModes
        savePowerModes()
        debugLog("🔄 Reset to default Power Modes")
    }

    // MARK: - Context Detection

    /// Detect current context and apply appropriate Power Mode
    func detectAndApplyPowerMode() {
        guard isEnabled else {
            debugLog("⚠️ Power Modes disabled, using global settings")
            currentPowerMode = nil
            return
        }

        // Get current app
        currentAppIdentifier = getFrontmostAppIdentifier()

        // Get current website (if browser)
        if let appId = currentAppIdentifier, ActiveBrowserInspector.isBrowser(appId) {
            currentWebsiteURL = ActiveBrowserInspector.frontmostTabURL()?.absoluteString
        } else {
            currentWebsiteURL = nil
        }

        debugLog("🔍 Detecting Power Mode...")
        debugLog("   App: \(currentAppIdentifier ?? "unknown")")
        debugLog("   URL: \(currentWebsiteURL ?? "N/A")")

        // Find matching Power Mode
        let matchingMode = findMatchingPowerMode()

        if let mode = matchingMode {
            applyPowerMode(mode)
        } else {
            // No match found — revert to global settings if we had a mode active
            if currentPowerMode != nil {
                debugLog("   No matching Power Mode, reverting to global settings")
                currentPowerMode = nil
                revertToGlobalSettings()
            } else {
                debugLog("   No matching Power Mode found, using global settings")
            }
        }
    }

    private func findMatchingPowerMode() -> PowerMode? {
        let matches = powerModes.filter { mode in
            mode.matches(appIdentifier: currentAppIdentifier, websiteURL: currentWebsiteURL)
        }

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
            powerModes[index].priority = max(0, min(100, priority))
            powerModes[index].dateModified = Date()
            savePowerModes()
            debugLog("✏️ Updated priority for \(powerModes[index].name) to \(priority)")
        }
    }

    /// Reorder power modes by priority
    func reorderByPriority() {
        powerModes.sort { $0.priority > $1.priority }
        savePowerModes()
    }

    private func applyPowerMode(_ mode: PowerMode) {
        guard mode.id != currentPowerMode?.id else {
            debugLog("   ✅ Already using: \(mode.emoji) \(mode.name)")
            return
        }

        debugLog("   🎯 Applying Power Mode: \(mode.emoji) \(mode.name)")

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

        debugLog("   ⚙️ Applying Power Mode settings:")

        // AI Enhancement
        if mode.aiEnhancementEnabled {
            settings.aiEnhancementEnabled = true
            if let model = mode.enhancementModel {
                settings.selectedEnhancementModel = model
                debugLog("      AI Enhancement: ✅ (\(model))")
            }
            if let prompt = mode.customEnhancementPrompt {
                settings.customEnhancementPrompt = prompt
            }
        } else {
            settings.aiEnhancementEnabled = false
            debugLog("      AI Enhancement: ❌")
        }

        // Auto-Send
        settings.autoSendEnabled = mode.autoSendEnabled
        debugLog("      Auto-Send: \(mode.autoSendEnabled ? "✅" : "❌")")

        // Language
        if let language = mode.preferredLanguage {
            settings.preferredLanguage = language
            debugLog("      Language: \(language)")
        }

        // Apply model selection (Whisper vs Cloud)
        if let cloudModelId = mode.cloudModelId, !cloudModelId.isEmpty {
            let canonicalModelId = AppSettings.canonicalTranscriptionModelID(cloudModelId)
            settings.defaultTranscriptionModel = canonicalModelId
            debugLog("      Model: Cloud (\(canonicalModelId))")
        } else if mode.useWhisper, let whisperSize = mode.whisperModelSize {
            let canonicalModelId = AppSettings.canonicalTranscriptionModelID("whisper-\(whisperSize)")
            settings.defaultTranscriptionModel = canonicalModelId
            debugLog("      Model: Whisper (\(canonicalModelId))")
        }
    }

    /// Reverts settings to global defaults when no Power Mode matches
    private func revertToGlobalSettings() {
        // Post notification so UI can respond
        NotificationCenter.default.post(
            name: NSNotification.Name("PowerModeChanged"),
            object: nil
        )
        debugLog("   ⚙️ Reverted to global settings")
    }

    // MARK: - Helper Methods

    private func getFrontmostAppIdentifier() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return app.bundleIdentifier
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
            debugLog("📂 Loaded \(powerModes.count) Power Modes from storage")
        } else {
            powerModes = PowerMode.defaultModes
            savePowerModes()
            debugLog("📂 Initialized with default Power Modes")
        }
    }

    private func loadEnabledState() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        } else {
            isEnabled = true
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        }

        if UserDefaults.standard.object(forKey: autoSwitchKey) != nil {
            isAutoSwitchEnabled = UserDefaults.standard.bool(forKey: autoSwitchKey)
        } else {
            isAutoSwitchEnabled = true
            UserDefaults.standard.set(isAutoSwitchEnabled, forKey: autoSwitchKey)
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)

        if enabled {
            debugLog("✅ Power Modes enabled")
            detectAndApplyPowerMode()
        } else {
            debugLog("❌ Power Modes disabled")
            currentPowerMode = nil
        }
    }

    func setAutoSwitchEnabled(_ enabled: Bool) {
        isAutoSwitchEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: autoSwitchKey)
        debugLog(enabled ? "✅ Auto-switch enabled" : "❌ Auto-switch disabled")
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
