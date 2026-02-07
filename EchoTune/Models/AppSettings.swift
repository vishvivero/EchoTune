//
//  AppSettings.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import Combine
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    // General Settings
    @Published var launchAtStartup: Bool {
        didSet { UserDefaults.standard.set(launchAtStartup, forKey: "launchAtStartup") }
    }
    
    @Published var recordingMode: RecordingMode {
        didSet { UserDefaults.standard.set(recordingMode.rawValue, forKey: "recordingMode") }
    }
    
    // Model Settings
    @Published var selectedModelSize: ModelSize {
        didSet { UserDefaults.standard.set(selectedModelSize.rawValue, forKey: "selectedModelSize") }
    }

    @Published var defaultTranscriptionModel: String {
        didSet { UserDefaults.standard.set(defaultTranscriptionModel, forKey: "defaultTranscriptionModel") }
    }

    @Published var preferredLanguage: String {
        didSet { UserDefaults.standard.set(preferredLanguage, forKey: "preferredLanguage") }
    }
    
    // Privacy Settings
    @Published var keepAudioHistory: Bool {
        didSet { UserDefaults.standard.set(keepAudioHistory, forKey: "keepAudioHistory") }
    }
    
    @Published var shareAnalytics: Bool {
        didSet { UserDefaults.standard.set(shareAnalytics, forKey: "shareAnalytics") }
    }
    
    // Advanced Settings
    @Published var autoPunctuation: Bool {
        didSet { UserDefaults.standard.set(autoPunctuation, forKey: "autoPunctuation") }
    }

    @Published var smartCapitalization: Bool {
        didSet { UserDefaults.standard.set(smartCapitalization, forKey: "smartCapitalization") }
    }

    @Published var insertSpaceAfterText: Bool {
        didSet { UserDefaults.standard.set(insertSpaceAfterText, forKey: "insertSpaceAfterText") }
    }

    // Toggle for auto-correction of in-speech corrections (e.g. "Sorry, I meant ...")
    @Published var autoCorrection: Bool {
        didSet { UserDefaults.standard.set(autoCorrection, forKey: "autoCorrection") }
    }

    @Published var showInDock: Bool {
        didSet { UserDefaults.standard.set(showInDock, forKey: "showInDock") }
    }

    @Published var showInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
            // Notify AppDelegate to show/hide menu bar icon
            NotificationCenter.default.post(name: NSNotification.Name("MenuBarVisibilityChanged"), object: showInMenuBar)
        }
    }

    // Audio Feedback Settings
    @Published var playSoundOnStartStop: Bool {
        didSet { UserDefaults.standard.set(playSoundOnStartStop, forKey: "playSoundOnStartStop") }
    }

    @Published var muteBackgroundAudio: Bool {
        didSet { UserDefaults.standard.set(muteBackgroundAudio, forKey: "muteBackgroundAudio") }
    }

    // Shortcut Settings
    @Published var activationShortcut: String {
        didSet { UserDefaults.standard.set(activationShortcut, forKey: "activationShortcut") }
    }
    
    // Theme Settings
    @Published var appTheme: AppTheme {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }
    
    // License Settings
    @Published var licenseKey: String {
        didSet { UserDefaults.standard.set(licenseKey, forKey: "licenseKey") }
    }

    // Phase 6A: Auto-Send Settings
    @Published var autoSendEnabled: Bool {
        didSet { UserDefaults.standard.set(autoSendEnabled, forKey: "autoSendEnabled") }
    }

    // Phase 6A: AI Enhancement Settings
    @Published var aiEnhancementEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnhancementEnabled, forKey: "aiEnhancementEnabled") }
    }

    @Published var selectedEnhancementModel: String {
        didSet { UserDefaults.standard.set(selectedEnhancementModel, forKey: "selectedEnhancementModel") }
    }

    @Published var customEnhancementPrompt: String {
        didSet { UserDefaults.standard.set(customEnhancementPrompt, forKey: "customEnhancementPrompt") }
    }

    // Phase 6A: API Keys (stored securely in Keychain in production)
    @Published var groqAPIKey: String {
        didSet { UserDefaults.standard.set(groqAPIKey, forKey: "groqAPIKey") }
    }

    @Published var openaiAPIKey: String {
        didSet { UserDefaults.standard.set(openaiAPIKey, forKey: "openaiAPIKey") }
    }

    @Published var claudeAPIKey: String {
        didSet { UserDefaults.standard.set(claudeAPIKey, forKey: "claudeAPIKey") }
    }

    @Published var deepgramAPIKey: String {
        didSet { UserDefaults.standard.set(deepgramAPIKey, forKey: "deepgramAPIKey") }
    }

    @Published var anthropicAPIKey: String {
        didSet { UserDefaults.standard.set(anthropicAPIKey, forKey: "anthropicAPIKey") }
    }

    // Phase 6A: Social Share Settings
    @Published var hasSharedForDiscount: Bool {
        didSet { UserDefaults.standard.set(hasSharedForDiscount, forKey: "hasSharedForDiscount") }
    }

    @Published var socialShareDiscountCode: String? {
        didSet { UserDefaults.standard.set(socialShareDiscountCode, forKey: "socialShareDiscountCode") }
    }

    // Recorder UI Style
    @Published var recorderStyle: RecorderStyle {
        didSet { UserDefaults.standard.set(recorderStyle.rawValue, forKey: "recorderStyle") }
    }

    // Phase 6C: Auto-Update Settings
    @Published var automaticUpdatesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticUpdatesEnabled, forKey: "automaticUpdatesEnabled")
            UpdateManager.shared.setAutomaticUpdates(enabled: automaticUpdatesEnabled)
        }
    }

    @Published var checkForBetaUpdates: Bool {
        didSet { UserDefaults.standard.set(checkForBetaUpdates, forKey: "checkForBetaUpdates") }
    }

    init() {
        // Load settings from UserDefaults
        self.launchAtStartup = UserDefaults.standard.bool(forKey: "launchAtStartup")
        
        if let recordingModeValue = UserDefaults.standard.string(forKey: "recordingMode"),
           let mode = RecordingMode(rawValue: recordingModeValue) {
            self.recordingMode = mode
        } else {
            self.recordingMode = .pushToTalk
        }
        
        if let modelSizeValue = UserDefaults.standard.string(forKey: "selectedModelSize"),
           let size = ModelSize(rawValue: modelSizeValue) {
            self.selectedModelSize = size
        } else {
            self.selectedModelSize = .balanced
        }

        self.defaultTranscriptionModel = UserDefaults.standard.string(forKey: "defaultTranscriptionModel") ?? "apple-speech"

        self.preferredLanguage = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "en-US"
        self.keepAudioHistory = UserDefaults.standard.bool(forKey: "keepAudioHistory")
        self.shareAnalytics = UserDefaults.standard.bool(forKey: "shareAnalytics")
        self.autoPunctuation = UserDefaults.standard.bool(forKey: "autoPunctuation")
        self.smartCapitalization = UserDefaults.standard.bool(forKey: "smartCapitalization")
        self.insertSpaceAfterText = UserDefaults.standard.bool(forKey: "insertSpaceAfterText")
        // Initialize autoCorrection toggle
        if UserDefaults.standard.object(forKey: "autoCorrection") != nil {
            self.autoCorrection = UserDefaults.standard.bool(forKey: "autoCorrection")
        } else {
            self.autoCorrection = true // default ON
        }
        self.showInDock = UserDefaults.standard.bool(forKey: "showInDock")

        // Show in menu bar (default ON)
        if UserDefaults.standard.object(forKey: "showInMenuBar") != nil {
            self.showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
        } else {
            self.showInMenuBar = true // default ON
        }

        // Audio Feedback Settings
        if UserDefaults.standard.object(forKey: "playSoundOnStartStop") != nil {
            self.playSoundOnStartStop = UserDefaults.standard.bool(forKey: "playSoundOnStartStop")
        } else {
            self.playSoundOnStartStop = true // default ON (recommended)
        }

        if UserDefaults.standard.object(forKey: "muteBackgroundAudio") != nil {
            self.muteBackgroundAudio = UserDefaults.standard.bool(forKey: "muteBackgroundAudio")
        } else {
            self.muteBackgroundAudio = true // default ON
        }

        self.activationShortcut = UserDefaults.standard.string(forKey: "activationShortcut") ?? "⌃"
        
        if let themeValue = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: themeValue) {
            self.appTheme = theme
        } else {
            self.appTheme = .system
        }
        
        self.licenseKey = UserDefaults.standard.string(forKey: "licenseKey") ?? ""

        // Phase 6A: Initialize Auto-Send Settings
        if UserDefaults.standard.object(forKey: "autoSendEnabled") != nil {
            self.autoSendEnabled = UserDefaults.standard.bool(forKey: "autoSendEnabled")
        } else {
            self.autoSendEnabled = false // default OFF (user must opt-in)
        }

        // Phase 6A: Initialize AI Enhancement Settings
        if UserDefaults.standard.object(forKey: "aiEnhancementEnabled") != nil {
            self.aiEnhancementEnabled = UserDefaults.standard.bool(forKey: "aiEnhancementEnabled")
        } else {
            self.aiEnhancementEnabled = false // default OFF (requires API key)
        }

        self.selectedEnhancementModel = UserDefaults.standard.string(forKey: "selectedEnhancementModel") ?? "gpt-4o-mini"
        self.customEnhancementPrompt = UserDefaults.standard.string(forKey: "customEnhancementPrompt") ?? ""

        // Phase 6A: Initialize API Keys
        self.groqAPIKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        self.openaiAPIKey = UserDefaults.standard.string(forKey: "openaiAPIKey") ?? ""
        self.claudeAPIKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        self.deepgramAPIKey = UserDefaults.standard.string(forKey: "deepgramAPIKey") ?? ""
        self.anthropicAPIKey = UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""

        // Phase 6A: Initialize Social Share Settings
        if UserDefaults.standard.object(forKey: "hasSharedForDiscount") != nil {
            self.hasSharedForDiscount = UserDefaults.standard.bool(forKey: "hasSharedForDiscount")
        } else {
            self.hasSharedForDiscount = false
        }
        self.socialShareDiscountCode = UserDefaults.standard.string(forKey: "socialShareDiscountCode")

        // Recorder Style
        if let recorderStyleValue = UserDefaults.standard.string(forKey: "recorderStyle"),
           let style = RecorderStyle(rawValue: recorderStyleValue) {
            self.recorderStyle = style
        } else {
            self.recorderStyle = .slim // default: slim bottom bar
        }

        // Phase 6C: Initialize Auto-Update Settings
        if UserDefaults.standard.object(forKey: "automaticUpdatesEnabled") != nil {
            self.automaticUpdatesEnabled = UserDefaults.standard.bool(forKey: "automaticUpdatesEnabled")
        } else {
            self.automaticUpdatesEnabled = true // Default to enabled
        }

        if UserDefaults.standard.object(forKey: "checkForBetaUpdates") != nil {
            self.checkForBetaUpdates = UserDefaults.standard.bool(forKey: "checkForBetaUpdates")
        } else {
            self.checkForBetaUpdates = false // Default to stable releases only
        }

        // Set defaults if first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            setDefaults()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    private func setDefaults() {
        self.launchAtStartup = false
        self.recordingMode = .toggle
        self.selectedModelSize = .balanced
        self.preferredLanguage = "en-US"
        self.keepAudioHistory = false
        self.shareAnalytics = false
        self.autoPunctuation = true
        self.smartCapitalization = true
        self.insertSpaceAfterText = true
        self.autoCorrection = true
        self.showInDock = false
        self.showInMenuBar = true  // default ON
        self.playSoundOnStartStop = true
        self.muteBackgroundAudio = true
        self.activationShortcut = "⌃"
        self.appTheme = .system
    }
    
    // Reset all settings to default values
    func resetToDefaults() {
        setDefaults()
    }
}

// Enums for settings
enum RecordingMode: String, CaseIterable, Identifiable {
    case pushToTalk = "Push to Talk"
    case toggle = "Toggle"

    var id: String { self.rawValue }

    var description: String {
        switch self {
        case .pushToTalk:
            return "Hold shortcut key to record"
        case .toggle:
            return "Press once to start, press again to stop"
        }
    }
}

enum ModelSize: String, CaseIterable, Identifiable {
    case fast = "Fast"
    case balanced = "Balanced"
    case accurate = "Accurate"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .fast:
            return "Tiny model (27MB) - 5-10x realtime, good accuracy"
        case .balanced:
            return "Base model (140MB) - 2-3x realtime, very good accuracy"
        case .accurate:
            return "Small model (550MB) - 1x realtime, excellent accuracy"
        }
    }
    
    var fileSize: String {
        switch self {
        case .fast: return "27MB"
        case .balanced: return "140MB"
        case .accurate: return "550MB"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { self.rawValue }
}

enum RecorderStyle: String, CaseIterable, Identifiable {
    case slim = "Slim Bar"
    case notch = "Notch Recorder"
    case mini = "Mini Panel"

    var id: String { self.rawValue }

    var description: String {
        switch self {
        case .slim:
            return "Compact bar at the bottom of the screen"
        case .notch:
            return "Compact pill that hugs the MacBook notch area"
        case .mini:
            return "Floating panel with waveform and timer (draggable)"
        }
    }
}