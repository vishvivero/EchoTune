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
    private var applyingModelLanguageDefault = false
    // General Settings
    @Published var recordingMode: RecordingMode {
        didSet { UserDefaults.standard.set(recordingMode.rawValue, forKey: "recordingMode") }
    }

    /// Controls how often the live preview requests a decode. Classic keeps
    /// the pre-Phase-7 four-second behavior as a rollback tier.
    @Published var previewTier: PreviewTier {
        didSet { UserDefaults.standard.set(previewTier.rawValue, forKey: "previewTier") }
    }
    
    // Model Settings
    @Published var defaultTranscriptionModel: String {
        didSet { UserDefaults.standard.set(defaultTranscriptionModel, forKey: "defaultTranscriptionModel") }
    }

    @Published var groqCloudTranscriptionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(groqCloudTranscriptionEnabled, forKey: "groqCloudTranscriptionEnabled")

            if groqCloudTranscriptionEnabled, !groqAPIKey.isEmpty {
                if defaultTranscriptionModel != "groq-whisper-large-v3-turbo" {
                    defaultTranscriptionModel = "groq-whisper-large-v3-turbo"
                }
            } else if defaultTranscriptionModel == "groq-whisper-large-v3-turbo" {
                defaultTranscriptionModel = Self.defaultLocalTranscriptionModel
            }
        }
    }

    @Published var preferredLanguage: String {
        didSet {
            UserDefaults.standard.set(preferredLanguage, forKey: "preferredLanguage")
            guard !applyingModelLanguageDefault,
                  let modelID = UserDefaults.standard.string(forKey: "defaultTranscriptionModel") else { return }
            UserDefaults.standard.set(true, forKey: "languageOverriddenFor_\(modelID)")
        }
    }

    /// Applies a fixed-language model's initial default without marking it as
    /// a user override. Later manual edits to preferredLanguage are preserved.
    func applyModelLanguageDefault(_ language: String, modelID: String) {
        guard !language.isEmpty,
              !UserDefaults.standard.bool(forKey: "languageOverriddenFor_\(modelID)") else { return }
        applyingModelLanguageDefault = true
        if preferredLanguage != language {
            preferredLanguage = language
        }
        applyingModelLanguageDefault = false
    }

    @Published var autoDetectLanguage: Bool {
        didSet { UserDefaults.standard.set(autoDetectLanguage, forKey: "autoDetectLanguage") }
    }

    @Published var translateToEnglish: Bool {
        didSet { UserDefaults.standard.set(translateToEnglish, forKey: "translateToEnglish") }
    }

    /// Inject explicitly configured vocabulary into decoder prompts. The
    /// post-hoc dictionary safety net remains active regardless of this flag.
    @Published var vocabularyBiasingEnabled: Bool {
        didSet { UserDefaults.standard.set(vocabularyBiasingEnabled, forKey: "vocabularyBiasingEnabled") }
    }

    // Privacy Settings
    @Published var keepAudioHistory: Bool {
        didSet { UserDefaults.standard.set(keepAudioHistory, forKey: "keepAudioHistory") }
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

    // Audio Feedback Settings
    @Published var playSoundOnStartStop: Bool {
        didSet { UserDefaults.standard.set(playSoundOnStartStop, forKey: "playSoundOnStartStop") }
    }

    @Published var muteBackgroundAudio: Bool {
        didSet { UserDefaults.standard.set(muteBackgroundAudio, forKey: "muteBackgroundAudio") }
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

    /// Removes model transport wrappers before enhanced text is inserted.
    @Published var stripEnhancementWrappers: Bool {
        didSet { UserDefaults.standard.set(stripEnhancementWrappers, forKey: "stripEnhancementWrappers") }
    }

    /// Stable per-install id used to key the hosted fair-use quota. Persisted once.
    let enhancementUserID: String

    /// Base URL of the hosted enhancement proxy (Netlify Function on echotune.app).
    var enhancementProxyURL: String {
        "https://echotune.app/.netlify/functions/enhance"
    }

    /// Human-facing daily fair-use cap, mirrored from the proxy env. Purely informational.
    var enhancementDailyLimit: Int { 50 }

    // Phase 6A: API Keys (stored securely in macOS Keychain)
    @Published var groqAPIKey: String {
        didSet {
            KeychainHelper.save(groqAPIKey, forKey: "groqAPIKey")
            NotificationCenter.default.post(name: NSNotification.Name("APIKeyChanged"), object: nil)

            if !groqAPIKey.isEmpty {
                if !groqCloudTranscriptionEnabled {
                    groqCloudTranscriptionEnabled = true
                } else if defaultTranscriptionModel != "groq-whisper-large-v3-turbo" {
                    defaultTranscriptionModel = "groq-whisper-large-v3-turbo"
                }
            } else if defaultTranscriptionModel == "groq-whisper-large-v3-turbo" {
                groqCloudTranscriptionEnabled = false
                defaultTranscriptionModel = Self.defaultLocalTranscriptionModel
            }
        }
    }

    @Published var openaiAPIKey: String {
        didSet {
            KeychainHelper.save(openaiAPIKey, forKey: "openaiAPIKey")
            NotificationCenter.default.post(name: NSNotification.Name("APIKeyChanged"), object: nil)
        }
    }

    /// Enables billable Deepgram WebSocket previews. Off by default for cost control.
    @Published var deepgramLiveEnabled: Bool {
        didSet { UserDefaults.standard.set(deepgramLiveEnabled, forKey: "deepgramLiveEnabled") }
    }

    @Published var deepgramAPIKey: String {
        didSet {
            KeychainHelper.save(deepgramAPIKey, forKey: "deepgramAPIKey")
            NotificationCenter.default.post(name: NSNotification.Name("APIKeyChanged"), object: nil)
        }
    }

    @Published var geminiAPIKey: String {
        didSet {
            KeychainHelper.save(geminiAPIKey, forKey: "geminiAPIKey")
            NotificationCenter.default.post(name: NSNotification.Name("APIKeyChanged"), object: nil)
        }
    }

    func apiKey(for provider: AIEnhancementEngine.EnhancementProvider) -> String {
        switch provider {
        case .hosted:
            return "" // Hosted path uses the proxy; no user key.
        case .groq:
            return groqAPIKey
        case .google:
            return geminiAPIKey
        case .openai:
            return openaiAPIKey
        }
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

    // Audio Cleanup Settings
    @Published var audioRetentionDays: Int {
        didSet { UserDefaults.standard.set(audioRetentionDays, forKey: "audioRetentionDays") }
    }

    // Phase 6C: Auto-Update Settings
    @Published var automaticUpdatesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(automaticUpdatesEnabled, forKey: "automaticUpdatesEnabled")
            UpdateManager.shared.setAutomaticUpdates(enabled: automaticUpdatesEnabled)
        }
    }

    init() {
        // Stable per-install id for hosted fair-use. Generate once, persist.
        if let stored = UserDefaults.standard.string(forKey: "enhancementUserID"), !stored.isEmpty {
            self.enhancementUserID = stored
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "enhancementUserID")
            self.enhancementUserID = newID
        }

        // Load settings from UserDefaults
        if let recordingModeValue = UserDefaults.standard.string(forKey: "recordingMode"),
           let mode = RecordingMode(rawValue: recordingModeValue) {
            self.recordingMode = mode
        } else {
            self.recordingMode = .pushToTalk
        }

        if let previewValue = UserDefaults.standard.string(forKey: "previewTier"),
           let previewTier = PreviewTier(rawValue: previewValue) {
            self.previewTier = previewTier
        } else {
            self.previewTier = .balanced
        }
        
        let hasGroqKey = !KeychainHelper.load(forKey: "groqAPIKey").isEmpty || !(UserDefaults.standard.string(forKey: "groqAPIKey") ?? "").isEmpty

        let groqCloudEnabled: Bool
        if UserDefaults.standard.object(forKey: "groqCloudTranscriptionEnabled") != nil {
            groqCloudEnabled = UserDefaults.standard.bool(forKey: "groqCloudTranscriptionEnabled")
        } else {
            groqCloudEnabled = hasGroqKey
        }
        self.groqCloudTranscriptionEnabled = groqCloudEnabled

        self.defaultTranscriptionModel = Self.migratedDefaultTranscriptionModel(
            UserDefaults.standard.string(forKey: "defaultTranscriptionModel"),
            hasGroqKey: hasGroqKey
        )

        self.preferredLanguage = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "en-US"
        self.autoDetectLanguage = UserDefaults.standard.object(forKey: "autoDetectLanguage") as? Bool ?? true
        self.translateToEnglish = UserDefaults.standard.object(forKey: "translateToEnglish") as? Bool ?? false
        self.vocabularyBiasingEnabled = UserDefaults.standard.object(forKey: "vocabularyBiasingEnabled") as? Bool ?? true
        self.keepAudioHistory = UserDefaults.standard.bool(forKey: "keepAudioHistory")
        self.autoPunctuation = UserDefaults.standard.bool(forKey: "autoPunctuation")
        self.smartCapitalization = UserDefaults.standard.bool(forKey: "smartCapitalization")
        self.insertSpaceAfterText = UserDefaults.standard.bool(forKey: "insertSpaceAfterText")
        // Initialize autoCorrection toggle
        if UserDefaults.standard.object(forKey: "autoCorrection") != nil {
            self.autoCorrection = UserDefaults.standard.bool(forKey: "autoCorrection")
        } else {
            self.autoCorrection = true // default ON
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

        self.selectedEnhancementModel = Self.migratedEnhancementModelSelection(UserDefaults.standard.string(forKey: "selectedEnhancementModel"))
        self.customEnhancementPrompt = UserDefaults.standard.string(forKey: "customEnhancementPrompt") ?? ""
        self.stripEnhancementWrappers = UserDefaults.standard.object(forKey: "stripEnhancementWrappers") as? Bool ?? true

        // Phase 6A: Initialize API Keys (from Keychain)
        self.groqAPIKey = KeychainHelper.load(forKey: "groqAPIKey")
        self.openaiAPIKey = KeychainHelper.load(forKey: "openaiAPIKey")
        self.deepgramLiveEnabled = UserDefaults.standard.object(forKey: "deepgramLiveEnabled") as? Bool ?? false
        self.deepgramAPIKey = KeychainHelper.load(forKey: "deepgramAPIKey")
        self.geminiAPIKey = KeychainHelper.load(forKey: "geminiAPIKey")

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
            self.recorderStyle = RecorderStyle.userFacingOptions.contains(style) ? style : .mini
        } else {
            self.recorderStyle = .mini // default: floating live preview panel
        }

        // Audio Cleanup Settings
        if UserDefaults.standard.object(forKey: "audioRetentionDays") != nil {
            self.audioRetentionDays = UserDefaults.standard.integer(forKey: "audioRetentionDays")
        } else {
            self.audioRetentionDays = 7 // default 7 days
        }

        // Phase 6C: Initialize Auto-Update Settings
        if UserDefaults.standard.object(forKey: "automaticUpdatesEnabled") != nil {
            self.automaticUpdatesEnabled = UserDefaults.standard.bool(forKey: "automaticUpdatesEnabled")
        } else {
            self.automaticUpdatesEnabled = true // Default to enabled
        }

        // Set defaults if first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            setDefaults()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }

        // Migrate any API keys still in UserDefaults to Keychain
        migrateAPIKeysToKeychain()
    }

    private func migrateAPIKeysToKeychain() {
        let keys = ["groqAPIKey", "openaiAPIKey", "deepgramAPIKey", "geminiAPIKey"]
        for key in keys {
            if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
                if KeychainHelper.load(forKey: key).isEmpty {
                    KeychainHelper.save(value, forKey: key)
                }
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        // After migration, reload keys from Keychain (in case migration populated them)
        self.groqAPIKey = KeychainHelper.load(forKey: "groqAPIKey")
        self.openaiAPIKey = KeychainHelper.load(forKey: "openaiAPIKey")
        self.deepgramAPIKey = KeychainHelper.load(forKey: "deepgramAPIKey")
        self.geminiAPIKey = KeychainHelper.load(forKey: "geminiAPIKey")
    }

    static let defaultLocalTranscriptionModel = "distil-whisper_distil-large-v3_turbo_600MB"
    private static let defaultEnhancementModel = AIEnhancementEngine.EnhancementModel.hosted.rawValue

    static func canonicalTranscriptionModelID(_ rawValue: String) -> String {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        let legacyMap: [String: String] = [
            "whisper-tiny": defaultLocalTranscriptionModel,
            "whisper-base": "base",
            "whisper-small": defaultLocalTranscriptionModel,
            "whisper-medium": defaultLocalTranscriptionModel,
            "whisper-large-v3": "openai_whisper-large-v3-turbo",
            "whisper-large-v3-turbo": "openai_whisper-large-v3-turbo",
            "large-v3": "openai_whisper-large-v3-turbo",
            "distil-large-v3": "openai_whisper-base",
            "distil-large-v3-turbo": defaultLocalTranscriptionModel,
            "distil-whisper_distil-large-v3": "openai_whisper-base",
            "distil-whisper_distil-large-v3_turbo": defaultLocalTranscriptionModel,
            "parakeet": "parakeet-tdt-0.6b-v3",
            "parakeet-v3": "parakeet-tdt-0.6b-v3",
            "parakeet-v2": "parakeet-tdt-0.6b-v2"
        ]

        if let mapped = legacyMap[normalized] {
            return mapped
        }

        return normalized
    }

    private static func migratedDefaultTranscriptionModel(_ storedValue: String?, hasGroqKey: Bool) -> String {
        guard let storedValue, !storedValue.isEmpty else {
            return hasGroqKey ? "groq-whisper-large-v3-turbo" : defaultLocalTranscriptionModel
        }

        return canonicalTranscriptionModelID(storedValue)
    }

    private static func migratedEnhancementModelSelection(_ storedValue: String?) -> String {
        guard let storedValue, !storedValue.isEmpty else {
            return defaultEnhancementModel
        }

        if storedValue == "gpt-5.4" {
            return AIEnhancementEngine.EnhancementModel.hosted.rawValue
        }

        let retiredModels = [
            "gpt-4o-mini",
            "gpt-4o",
            "claude-3-5-sonnet-20241022",
            "claude-3-opus-20240229"
        ]

        if retiredModels.contains(storedValue) {
            return defaultEnhancementModel
        }

        return AIEnhancementEngine.EnhancementModel(rawValue: storedValue)?.rawValue ?? defaultEnhancementModel
    }

    
    private func setDefaults() {
        self.recordingMode = .toggle
        self.previewTier = .balanced
        self.groqCloudTranscriptionEnabled = false
        self.preferredLanguage = "en-US"
        self.autoDetectLanguage = true
        self.translateToEnglish = false
        self.vocabularyBiasingEnabled = true
        self.keepAudioHistory = false
        self.autoPunctuation = true
        self.smartCapitalization = true
        self.insertSpaceAfterText = true
        self.autoCorrection = true
        self.playSoundOnStartStop = true
        self.muteBackgroundAudio = true
    }
    
    // Reset all settings to default values
    func resetToDefaults() {
        setDefaults()
        // Clear API keys from Keychain
        KeychainHelper.delete(forKey: "groqAPIKey")
        KeychainHelper.delete(forKey: "openaiAPIKey")
        KeychainHelper.delete(forKey: "deepgramAPIKey")
        KeychainHelper.delete(forKey: "geminiAPIKey")
        self.groqAPIKey = ""
        self.openaiAPIKey = ""
        self.deepgramAPIKey = ""
        self.geminiAPIKey = ""
        self.groqCloudTranscriptionEnabled = false
    }
}

// Enums for settings
enum PreviewTier: String, CaseIterable, Identifiable {
    case classic
    case balanced
    case reactive

    var id: String { rawValue }

    var interval: TimeInterval {
        switch self {
        case .classic: return 4.0
        case .balanced: return 2.0
        case .reactive: return 1.0
        }
    }

    var title: String {
        switch self {
        case .classic: return "Classic (4 seconds)"
        case .balanced: return "Balanced (2 seconds)"
        case .reactive: return "Reactive (1 second)"
        }
    }

    var description: String {
        switch self {
        case .classic: return "The original lower-frequency preview behavior."
        case .balanced: return "A faster preview with moderate decode overhead."
        case .reactive: return "The fastest preview; may use more CPU and GPU."
        }
    }
}

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

enum RecorderStyle: String, CaseIterable, Identifiable {
    case slim = "Slim Bar"
    case mini = "Mini Panel"

    var id: String { self.rawValue }

    static var userFacingOptions: [RecorderStyle] {
        [.slim, .mini]
    }

    var description: String {
        switch self {
        case .slim:
            return "Compact text bar that stays out of the way"
        case .mini:
            return "Floating panel with waveform and timer (draggable)"
        }
    }
}
