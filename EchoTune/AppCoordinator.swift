//
//  AppCoordinator.swift
//  EchoTune
//
//  Phase 2-5: Main Application Coordinator with Real Managers
//  Core class definition, properties, and initialization.
//
//  Extensions:
//    AppCoordinator+Recording.swift       — Dictation start/stop, recording logic
//    AppCoordinator+Transcription.swift    — Whisper/Apple Speech result handling, text processing
//    AppCoordinator+Retranscription.swift  — Re-transcription of saved audio
//

import Foundation
import Combine
import AppKit
import Speech
import ApplicationServices
import os.log

let appLog = OSLog(subsystem: "com.echotune.EchoTune", category: "debug")

struct FinalizedTranscription {
    let outputText: String
    let originalText: String
    let translatedText: String?
    let detectedLanguage: String?
    /// Already-decoded committed segments. When set, this text starts
    /// streaming into the target app IMMEDIATELY at stop, before the final
    /// tail decode lands with any corrections in outputText.
    var preStreamText: String? = nil
}

enum TranscriptionQualityFeedback: String, CaseIterable, Codable, Identifiable {
    case better = "Better"
    case same = "Same"
    case worse = "Worse"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .better: return "hand.thumbsup.fill"
        case .same: return "equal.circle.fill"
        case .worse: return "hand.thumbsdown.fill"
        }
    }
}

struct TranscriptionProcessingMetadata: Codable, Equatable {
    var transcriptionProvider: String?
    var transcriptionModel: String?
    var enhancementProvider: String?
    var enhancementModel: String?
    var audioByteCount: Int?
    var recordingDuration: TimeInterval?
    var transcriptionLatency: TimeInterval?
    var enhancementLatency: TimeInterval?
    var textInsertionLatency: TimeInterval?
    var totalLatency: TimeInterval?
    var usedFallback: Bool = false
    var fallbackReason: String?
    var userEdited: Bool = false
    var qualityFeedback: TranscriptionQualityFeedback?

    var hasEnhancement: Bool {
        enhancementProvider != nil || enhancementModel != nil
    }
}

class AppCoordinator: ObservableObject {
    @Published var showAbout = false
    @Published var showLicenseSheet = false
    @Published var showPurchaseSheet = false
    static let shared = AppCoordinator()

    // State
    var appState = AppState.shared
    var settings = AppSettings.shared

    // Managers (Phase 2, 3, 4 & 5: All Implemented!)
    // Made lazy to prevent triggering permission dialogs before onboarding completes
    lazy var audioManager = AudioManager.shared
    lazy var permissionsManager = PermissionsManager.shared
    lazy var shortcutManager = ShortcutManager.shared
    lazy var multiHotkeyManager = MultiHotkeyManager.shared // Phase 6C
    lazy var launchAtLoginManager = LaunchAtLoginManager.shared
    lazy var transcriptionEngine = TranscriptionEngine.shared
    lazy var whisperEngine = WhisperEngine.shared
    let modelManager = ModelManager.shared  // Safe — no permission triggers
    lazy var textInsertionManager = TextInsertionManager.shared
    let licenseManager = LicenseManager.shared  // Safe — no permission triggers
    let referralManager = ReferralManager.shared  // Safe — no permission triggers

    // Phase 5: Polish & Monitoring
    let notificationManager = NotificationManager.shared
    let analyticsManager = AnalyticsManager.shared
    let errorLogger = ErrorLogger.shared

    // Track which engine to use
    var useWhisper: Bool {
        guard let currentModel = modelManager.currentModel else { return false }
        // Use Whisper engine only for local, non-built-in models if they are installed and usable
        guard currentModel.category == .local && !currentModel.isBuiltIn else { return false }
        return modelManager.isInstalledAndUsable(currentModel)
    }

    // Track if we muted system output during this recording session
    var didMuteSystemOutput = false

    // Audio retention: store last recorded audio data for saving alongside transcription
    var lastRecordedAudioData: Data?

    // Pipeline audit state for the current transcription run
    var currentProcessingMetadata = TranscriptionProcessingMetadata()
    var recordingStartedAt: Date?
    var transcriptionPhaseStartedAt: Date?
    var enhancementPhaseStartedAt: Date?

    var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        debugLog("✓ AppCoordinator initialized")
        setupBindings()

        // Only initialize managers if onboarding already completed
        // Otherwise, defer to avoid triggering system dialogs before user sees onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if hasCompletedOnboarding {
            initializeAfterOnboarding()
        } else {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OnboardingCompleted"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                debugLog("📢 Onboarding completed - initializing managers and requesting permissions")
                self?.initializeAfterOnboarding()
            }
        }

        // Phase 5: Setup error logging and notifications
        errorLogger.setupCrashHandler()
        notificationManager.setupNotificationCategories()

        // Listen for accessibility permission changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AccessibilityPermissionGranted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("📢 Received AccessibilityPermissionGranted notification - refreshing keyboard shortcut...")
            self?.refreshKeyboardShortcut()
        }

        // Listen for purchase completion (App Store IAP)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PurchaseCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("📢 Received PurchaseCompleted notification - updating license state...")
            self?.updateLicenseState()
        }
    }

    // MARK: - Setup

    private func setupKeyboardShortcut() {
        shortcutManager.onShortcutTriggered = { [weak self] in
            guard let self = self else { return }
            debugLog("⌨️ Keyboard shortcut triggered!")

            // Double-check permissions before starting
            if !self.permissionsManager.hasAccessibilityPermission {
                debugLog("⚠️ Accessibility permission not granted - requesting now")
                self.permissionsManager.requestAccessibilityPermission()
                return
            }

            if AppSettings.shared.recordingMode == .pushToTalk {
                // Push-to-talk: key down always starts recording
                if self.appState.recordingState == .idle {
                    self.toggleDictation()
                }
            } else {
                // Toggle mode: press to start, press again to stop
                self.toggleDictation()
            }
        }

        shortcutManager.onShortcutReleased = { [weak self] in
            guard let self = self else { return }
            // Push-to-talk: key up stops recording
            if AppSettings.shared.recordingMode == .pushToTalk {
                if self.appState.recordingState == .recording {
                    debugLog("⌨️ Push-to-talk: key released, stopping recording")
                    self.toggleDictation()
                }
            }
        }

        debugLog("✅ Keyboard shortcut callback configured (push-to-talk + toggle modes)")
        debugLog("   Current shortcut: \(shortcutManager.getCurrentShortcutString())")
    }

    /// Called after onboarding completes (or on launch if already done).
    /// Requests permissions and sets up the keyboard shortcut.
    private func initializeAfterOnboarding() {
        // 1. Check accessibility silently — do NOT show the system prompt on every launch.
        //    The prompt is only shown when the user explicitly clicks "Grant" in settings.
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        debugLog("🔐 Accessibility permission: \(trusted ? "granted" : "not yet granted")")

        // 2. Check all permissions (non-prompting)
        checkPermissions()

        // 3. Setup keyboard shortcut
        setupKeyboardShortcut()

        // 3b. Bring up auxiliary hotkeys (paste last transcript, show window)
        //     now, so they register at launch instead of only when the user
        //     first opens Settings > Hotkeys.
        _ = multiHotkeyManager

        // 4. Start audio cleanup manager
        AudioCleanupManager.shared.startAutomaticCleanup()

        // Register sleep-wake prewarm observer (Apple-style instant startup)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // 5. PermissionsManager already polls every 2 seconds via startPermissionMonitoring().
        //    Listen for the notification it posts when permission is newly granted.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AccessibilityPermissionGranted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            debugLog("✅ Accessibility permission granted — registering shortcut")
            self?.shortcutManager.unregisterGlobalShortcut()
            self?.shortcutManager.registerGlobalShortcut()
            self?.updatePermissionState()
        }

        // 6. Pre-load the default Whisper model in the background at launch.
        //    This eliminates the cold-start delay on first transcription.
        //    Wait for ModelManager to finish scanning installed models first.
        if modelManager.isReady {
            preloadDefaultModel()
        } else {
            // Register observer BEFORE checking again to avoid race condition
            let observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ModelManagerReady"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.preloadDefaultModel()
            }
            // Double-check: if isReady became true between the first check and observer registration
            if modelManager.isReady {
                NotificationCenter.default.removeObserver(observer)
                preloadDefaultModel()
            }
        }
    }

    /// Pre-load the default transcription model at startup so the first
    /// dictation is instant. Runs on a background thread to avoid blocking UI.
    private func preloadDefaultModel() {
        guard let currentModel = modelManager.currentModel else {
            debugLog("⚠️ No default model set — skipping preload")
            return
        }

        // Only preload local Whisper models (not Apple Speech or cloud)
        guard currentModel.category == .local && !currentModel.isBuiltIn else {
            debugLog("ℹ️ Default model is \(currentModel.name) — no preload needed")
            return
        }

        guard currentModel.isInstalled else {
            debugLog("⚠️ Default model \(currentModel.name) not installed — skipping preload")
            return
        }

        // Skip if already loaded (e.g., rapid re-init)
        if whisperEngine.isAvailable && whisperEngine.loadedModelName == currentModel.name {
            debugLog("ℹ️ Model \(currentModel.name) already loaded — skipping preload")
            return
        }

        debugLog("🚀 Pre-loading default model at launch: \(currentModel.name)")
        debugLog("   Model: \(currentModel.name) (id: \(currentModel.id), category: \(currentModel.category))")

        whisperEngine.loadModel(currentModel) { result in
            switch result {
            case .success:
                debugLog("✅ Model pre-loaded and ready: \(currentModel.name)")
                debugLog("   whisperEngine.isAvailable=\(self.whisperEngine.isAvailable) loadedModelName=\(self.whisperEngine.loadedModelName ?? "nil")")
            case .failure(let error):
                debugLog("⚠️ Model preload failed (will retry on first dictation): \(error)")
            }
        }
    }

    private func setupBindings() {
        // Bind audio manager state to app state
        // Note: In a full Observable implementation, we'd use publishers
        // For now, we'll update manually in recording methods
    }

    // MARK: - Public API

    // Call this method when accessibility permission is granted
    func refreshKeyboardShortcut() {
        debugLog("🔄 Refreshing keyboard shortcut registration...")
        shortcutManager.unregisterGlobalShortcut()
        shortcutManager.registerGlobalShortcut()
    }

    func presentPurchaseFlow() {
        #if APPSTORE
        showPurchaseSheet = true
        #else
        let opened = licenseManager.openPurchaseURL()
        if !opened {
            showLicenseSheet = true
        }
        #endif
    }

    func setupApplication() {
        debugLog("Setting up application...")
        // Add any additional setup code here
    }

    func startNewTranscription() {
        debugLog("Starting new transcription...")
        startDictation()
    }

    // MARK: - Permissions (Phase 2: Real implementation)

    func checkPermissions() {
        permissionsManager.checkAllPermissions()
        updatePermissionState()
    }

    private func updatePermissionState() {
        appState.hasMicrophonePermission = permissionsManager.hasMicrophonePermission
        appState.hasAccessibilityPermission = permissionsManager.hasAccessibilityPermission
    }

    func updateLicenseState() {
        appState.isLicensed = licenseManager.isLicensed
        appState.licenseInfo = licenseManager.licenseInfo
    }

    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        permissionsManager.requestAllPermissions { [weak self] success in
            self?.updatePermissionState()
            completion(success)
        }
    }

    // MARK: - Recorder UI Helpers

    /// Shows the appropriate recorder UI based on user's selected style
    func showRecorderUI() {
        DispatchQueue.main.async {
            switch AppSettings.shared.recorderStyle {
            case .slim:
                RecordingIndicatorWindow.shared.show()
            case .mini:
                MiniRecorderWindow.shared.show()
            }
        }
    }

    /// Hides all recorder UIs
    func hideRecorderUI() {
        DispatchQueue.main.async {
            RecordingIndicatorWindow.shared.hide()
            MiniRecorderWindow.shared.hide()
        }
    }

    @objc private func handleSystemWake() {
        debugLog("🔋 System woke from sleep — pre-loading default model in 3 seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.preloadDefaultModel()
        }
    }
}
