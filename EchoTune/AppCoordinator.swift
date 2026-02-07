//
//  AppCoordinator.swift
//  EchoTune
//
//  Phase 2-5: Main Application Coordinator with Real Managers
//

import Foundation
import Combine
import AppKit
import Speech
import ApplicationServices

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

    // Phase 5: Polish & Monitoring
    let notificationManager = NotificationManager.shared
    let analyticsManager = AnalyticsManager.shared
    let errorLogger = ErrorLogger.shared

    // Track which engine to use
    private var useWhisper: Bool {
        guard let currentModel = modelManager.currentModel else { return false }
        // Use Whisper engine only for local, non-built-in models
        return currentModel.category == .local && !currentModel.isBuiltIn
    }

    // Track if we muted system output during this recording session
    private var didMuteSystemOutput = false

    // Phase 6B: Store screen context for current transcription
    private var currentScreenContext: ScreenContext?

    // Audio retention: store last recorded audio data for saving alongside transcription
    private var lastRecordedAudioData: Data?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("✓ AppCoordinator initialized")
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
                print("📢 Onboarding completed - initializing managers and requesting permissions")
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
            print("📢 Received AccessibilityPermissionGranted notification - refreshing keyboard shortcut...")
            self?.refreshKeyboardShortcut()
        }

        // Listen for purchase completion (App Store IAP)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PurchaseCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 Received PurchaseCompleted notification - updating license state...")
            self?.updateLicenseState()
        }
    }

    private func setupKeyboardShortcut() {
        shortcutManager.onShortcutTriggered = { [weak self] in
            guard let self = self else { return }
            print("⌨️ Keyboard shortcut triggered!")

            // Double-check permissions before starting
            if !self.permissionsManager.hasAccessibilityPermission {
                print("⚠️ Accessibility permission not granted - requesting now")
                self.permissionsManager.requestAccessibilityPermission()
                return
            }

            self.toggleDictation()
        }

        print("✅ Keyboard shortcut callback configured")
        print("   Current shortcut: \(shortcutManager.getCurrentShortcutString())")
    }

    /// Called after onboarding completes (or on launch if already done).
    /// Requests permissions and sets up the keyboard shortcut.
    private func initializeAfterOnboarding() {
        // 1. Request accessibility permission (triggers macOS prompt)
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("🔐 Accessibility permission: \(trusted ? "granted" : "requesting...")")

        // 2. Check all permissions
        checkPermissions()

        // 3. Setup keyboard shortcut
        setupKeyboardShortcut()

        // 4. Start audio cleanup manager
        AudioCleanupManager.shared.startAutomaticCleanup()

        // 5. If accessibility was just requested, poll for it
        if !trusted {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    print("✅ Accessibility permission granted — registering shortcut")
                    timer.invalidate()
                    self?.shortcutManager.unregisterGlobalShortcut()
                    self?.shortcutManager.registerGlobalShortcut()
                }
            }
        }
    }

    // Call this method when accessibility permission is granted
    func refreshKeyboardShortcut() {
        print("🔄 Refreshing keyboard shortcut registration...")
        shortcutManager.unregisterGlobalShortcut()
        shortcutManager.registerGlobalShortcut()
    }
    
    func setupApplication() {
        print("Setting up application...")
        // Add any additional setup code here
    }

    func startNewTranscription() {
        print("Starting new transcription...")
        startDictation()
    }

    private func setupBindings() {
        // Bind audio manager state to app state
        // Note: In a full Observable implementation, we'd use publishers
        // For now, we'll update manually in recording methods
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

    // MARK: - Dictation Actions (Phase 2: Real implementation!)

    func startDictation() {
        print("🎤 Start dictation")

        // Check if we can start
        guard canStartDictation() else {
            print("❌ Cannot start dictation - requirements not met")
            return
        }

        // ✅ CRITICAL OPTIMIZATION: Run context detection async to avoid blocking recording start
        // This makes dictation start INSTANTLY like VoiceInk
        DispatchQueue.global(qos: .userInitiated).async {
            // ✅ PHASE 6B: Detect and apply Power Mode (context-aware configuration)
            PowerModeManager.shared.detectAndApplyPowerMode()

            // ✅ PHASE 6B: Capture screen context (if enabled)
            DispatchQueue.main.async {
                self.currentScreenContext = ScreenContextService.shared.captureCurrentContext()
            }

            // ✅ PHASE 3: Detect browser context for context-aware transcription
            if let context = BrowserContextDetector.shared.detectContext() {
                print("🌐 Browser context: \(context.description)")
                if let hint = BrowserContextDetector.shared.getTranscriptionHint() {
                    print("   Hint: \(hint)")
                }
            }
        }

        // Get current model
        guard let currentModel = modelManager.currentModel else {
            print("❌ No model selected")
            showErrorAlert(message: "Please select a transcription model in AI Models settings")
            return
        }

        print("📍 Using model: \(currentModel.name) (Whisper: \(useWhisper))")

        // Load Whisper model if needed
        if useWhisper {
            if !whisperEngine.isAvailable || whisperEngine.loadedModelName != currentModel.name {
                print("📦 Loading Whisper model: \(currentModel.name)")

                // Show loading state
                appState.recordingState = .loadingModel(currentModel.name)

                // Update status bar to show loading
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let statusBar = appDelegate.statusBarController {
                    statusBar.updateIcon(for: .loadingModel(currentModel.name))
                }

                // Show notification to user
                notificationManager.showNotification(
                    title: "Loading Model",
                    body: "Loading \(currentModel.name)... This may take a moment for larger models.",
                    sound: false
                )

                whisperEngine.loadModel(currentModel) { [weak self] result in
                    guard let self = self else { return }

                    // Dismiss loading notification
                    self.notificationManager.dismissProcessingNotification()

                    switch result {
                    case .success:
                        print("✅ Whisper model loaded, starting dictation")

                        // Show success notification
                        self.notificationManager.showNotification(
                            title: "Model Ready",
                            body: "\(currentModel.name) loaded successfully!",
                            sound: false
                        )

                        // Reset state and start recording
                        self.appState.recordingState = .idle
                        self.beginRecording()

                    case .failure(let error):
                        print("❌ Failed to load Whisper model: \(error)")

                        // Reset state
                        self.appState.recordingState = .idle

                        // Update status bar
                        if let appDelegate = NSApp.delegate as? AppDelegate,
                           let statusBar = appDelegate.statusBarController {
                            statusBar.updateIcon(for: .idle)
                        }

                        self.showErrorAlert(message: "Failed to load model: \(error.localizedDescription)")
                    }
                }
                return
            }
        }

        // If a cloud model is selected, use cloud transcription
        if currentModel.category == .cloud {
            beginCloudRecording(model: currentModel)
            return
        }

        // Start recording with local model
        beginRecording()
    }

    // MARK: - Cloud Recording (Groq/Deepgram)

    private func beginCloudRecording(model: AIModel) {
        // Start performance monitoring
        PerformanceMonitor.shared.startRecording()

        // Play start sound (if enabled)
        SoundManager.shared.playStartSound()

        // Update state
        appState.recordingState = .recording

        // Mute system output while recording to avoid capturing app audio (if enabled)
        didMuteSystemOutput = false
        if AppSettings.shared.muteBackgroundAudio {
            SystemAudioManager.shared.muteSystemOutput()
            didMuteSystemOutput = true
        }

        // Show recording indicator (style-aware)
        showRecorderUI()

        // Start audio recording - we'll use the recorded audio for cloud transcription
        audioManager.startRecording()
        print("✓ Cloud recording started for: \(model.name)")

        // Update status bar icon
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .recording)
        }
    }

    private func stopCloudRecording() {
        print("🛑 Stop cloud recording")

        // Play stop sound (if enabled)
        SoundManager.shared.playStopSound()

        // Update state
        appState.recordingState = .processing

        // Hide recording indicator (all styles)
        hideRecorderUI()

        // Stop audio recording and get audio data for cloud transcription
        let engineType: AudioManager.AudioEngine = .whisper // Use Whisper-compatible format (Float32)
        guard let audioData = audioManager.stopRecording(forEngine: engineType) else {
            handleTranscriptionError("Failed to capture audio data")
            return
        }

        // Store audio data for retention
        self.lastRecordedAudioData = audioData
        
        print("📊 Captured \(audioData.count) bytes for cloud transcription")

        let recordingDuration = audioManager.lastRecordingDuration

        // Restore system output
        if didMuteSystemOutput {
            SystemAudioManager.shared.restoreSystemOutput()
            didMuteSystemOutput = false
        }

        // VAD: Check if there's significant speech
        if VADManager.shared.config.enabled {
            let hasSignificantSpeech = audioManager.hasSignificantSpeech()
            if !hasSignificantSpeech {
                print("⚠️ No significant speech detected - skipping cloud transcription")
                notificationManager.showNotification(
                    title: "No Speech Detected",
                    body: "The recording didn't contain any clear speech. Please try again.",
                    sound: false
                )
                appState.recordingState = .idle
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let statusBar = appDelegate.statusBarController {
                    statusBar.updateIcon(for: .idle)
                }
                return
            }
        }

        // Determine which cloud service to use based on model
        guard let currentModel = modelManager.currentModel else {
            handleTranscriptionError("No model selected")
            return
        }

        Task {
            do {
                let transcribedText: String

                // Route to appropriate cloud service
                if currentModel.id.contains("groq") || currentModel.name.lowercased().contains("groq") {
                    // Use Groq
                    let apiKey = settings.groqAPIKey
                    guard !apiKey.isEmpty else {
                        await MainActor.run {
                            handleTranscriptionError("Groq API key not configured. Please add your API key in Settings > API Keys.")
                        }
                        return
                    }

                    print("☁️ Transcribing with Groq...")
                    PerformanceMonitor.shared.startTranscription(engine: "Groq", model: "whisper-large-v3-turbo")
                    transcribedText = try await GroqTranscriptionService.shared.transcribe(
                        audioData: audioData,
                        language: settings.preferredLanguage.components(separatedBy: "-").first,
                        apiKey: apiKey
                    )

                } else if currentModel.id.contains("deepgram") || currentModel.name.lowercased().contains("deepgram") {
                    // Use Deepgram
                    let apiKey = settings.deepgramAPIKey
                    guard !apiKey.isEmpty else {
                        await MainActor.run {
                            handleTranscriptionError("Deepgram API key not configured. Please add your API key in Settings > API Keys.")
                        }
                        return
                    }

                    print("☁️ Transcribing with Deepgram...")
                    PerformanceMonitor.shared.startTranscription(engine: "Deepgram", model: "nova-2")
                    transcribedText = try await DeepgramTranscriptionService.shared.transcribeToText(
                        audioData: audioData,
                        model: .nova,
                        language: settings.preferredLanguage.components(separatedBy: "-").first,
                        apiKey: apiKey
                    )

                } else {
                    await MainActor.run {
                        handleTranscriptionError("Unknown cloud model: \(currentModel.name)")
                    }
                    return
                }

                await MainActor.run {
                    PerformanceMonitor.shared.endTranscription(wordCount: transcribedText.split(separator: " ").count)

                    print("✅ Cloud transcription successful: \(transcribedText)")
                    self.errorLogger.logInfo("Cloud transcription successful", category: "Transcription", context: [
                        "wordCount": "\(transcribedText.split(separator: " ").count)",
                        "recordingDuration": "\(String(format: "%.2f", recordingDuration))s",
                        "model": currentModel.name
                    ])

                    // Process and insert text
                    self.processAndInsertText(transcribedText, recordingDuration: recordingDuration)
                }

            } catch {
                await MainActor.run {
                    print("❌ Cloud transcription failed: \(error)")
                    self.errorLogger.logError(error, category: "Transcription", context: [
                        "model": currentModel.name
                    ])
                    self.handleTranscriptionError(error.localizedDescription)
                }
            }
        }

        // Update status bar
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .processing)
        }
    }

    // MARK: - Recorder UI Helpers

    /// Shows the appropriate recorder UI based on user's selected style
    private func showRecorderUI() {
        DispatchQueue.main.async {
            switch AppSettings.shared.recorderStyle {
            case .slim:
                RecordingIndicatorWindow.shared.show()
            case .notch:
                NotchRecorderWindow.shared.show()
            case .mini:
                MiniRecorderWindow.shared.show()
            }
        }
    }

    /// Hides all recorder UIs
    private func hideRecorderUI() {
        DispatchQueue.main.async {
            RecordingIndicatorWindow.shared.hide()
            NotchRecorderWindow.shared.hide()
            MiniRecorderWindow.shared.hide()
        }
    }

    private func beginRecording() {
        // Start performance monitoring
        PerformanceMonitor.shared.startRecording()

        // Play start sound (if enabled)
        SoundManager.shared.playStartSound()

        // Update state
        appState.recordingState = .recording

        // Mute system output while recording to avoid capturing app audio (if enabled)
        didMuteSystemOutput = false  // Reset flag
        if AppSettings.shared.muteBackgroundAudio {
            SystemAudioManager.shared.muteSystemOutput()
            didMuteSystemOutput = true  // Track that we muted
        }

        // Show recording indicator (style-aware)
        showRecorderUI()

        // Start audio recording
        audioManager.startRecording()
        print("✓ Recording started successfully")

        // Start transcription based on selected model
        if useWhisper {
            // Whisper streaming transcription
            print("🎯 Starting Whisper streaming transcription")

            whisperEngine.startStreamingTranscription { [weak self] result in
                guard let self = self else { return }
                self.handleWhisperResult(result)
            }

            // Set up callback to stream audio buffers to Whisper
            audioManager.onAudioBuffer = { [weak self] buffer in
                self?.whisperEngine.appendAudioBuffer(buffer)
            }
        } else {
            // Apple Speech live transcription
            if let audioFormat = audioManager.audioEngine?.inputNode.inputFormat(forBus: 0) {
                print("🎯 Starting Apple Speech live transcription")

                transcriptionEngine.startLiveTranscription(audioFormat: audioFormat) { [weak self] result in
                    guard let self = self else { return }
                    self.handleTranscriptionResult(result)
                }

                // Set up callback to stream audio buffers to Apple Speech
                audioManager.onAudioBuffer = { [weak self] buffer in
                    self?.transcriptionEngine.appendAudioBuffer(buffer)
                }
            } else {
                print("⚠️ Could not get audio format, live transcription not started")
            }
        }

        // Update status bar icon
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .recording)
        }
    }

    func stopDictation() {
        print("🛑 Stop dictation")

        // Play stop sound (if enabled)
        SoundManager.shared.playStopSound()

        // Update state
        appState.recordingState = .processing

        // Hide recording indicator (all styles)
        hideRecorderUI()

        // Clear the audio buffer callback
        audioManager.onAudioBuffer = nil

        // Stop audio recording with correct engine type (this calculates the duration)
        let engineType: AudioManager.AudioEngine = useWhisper ? .whisper : .appleSpeech
        let capturedAudioData = audioManager.stopRecording(forEngine: engineType)

        // Store audio data for retention
        self.lastRecordedAudioData = capturedAudioData

        // NOW read the recording duration (after it's been calculated)
        let recordingDuration = audioManager.lastRecordingDuration

        // End recording performance monitoring with correct duration
        PerformanceMonitor.shared.endRecording(
            duration: recordingDuration,
            bufferCount: 0  // Buffer count will be tracked internally in AudioManager
        )

        // Restore system output volume (if we actually muted it at start)
        if didMuteSystemOutput {
            SystemAudioManager.shared.restoreSystemOutput()
            didMuteSystemOutput = false  // Reset flag
        }

        // VAD: Check if there's significant speech before transcribing
        if VADManager.shared.config.enabled {
            print("🎙️ Performing VAD analysis...")
            let hasSignificantSpeech = audioManager.hasSignificantSpeech()

            if !hasSignificantSpeech {
                print("⚠️ No significant speech detected - skipping transcription")

                // Show "No speech detected" notification
                self.notificationManager.showNotification(
                    title: "No Speech Detected",
                    body: "The recording didn't contain any clear speech. Please try again.",
                    sound: false
                )

                // Log to analytics
                self.analyticsManager.recordError(type: "VAD", context: "No speech detected")

                // Reset state
                self.appState.recordingState = .idle

                // Update status bar
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let statusBar = appDelegate.statusBarController {
                    statusBar.updateIcon(for: .idle)
                }

                return  // Skip transcription entirely
            }

            // Log VAD analysis
            if let vadAnalysis = audioManager.getVADAnalysis() {
                print("📊 VAD Analysis:")
                print(vadAnalysis.summary)

                self.errorLogger.logInfo("VAD Analysis completed", category: "VAD", context: [
                    "speechPercentage": "\(vadAnalysis.speechPercentage)%",
                    "speechDuration": "\(vadAnalysis.speechDuration)s",
                    "segments": "\(vadAnalysis.speechSegments.count)"
                ])
            }
        }

        // End transcription based on which engine is being used
        if useWhisper {
            print("🛑 Ending Whisper transcription")
            whisperEngine.endStreamingTranscription { [weak self] result in
                guard let self = self else { return }
                self.handleWhisperResult(result)
            }
        } else {
            print("🛑 Ending Apple Speech transcription")
            PerformanceMonitor.shared.startTranscription(
                engine: "Apple Speech",
                model: "Built-in"
            )
            transcriptionEngine.endLiveTranscription()
        }

        // Update status bar icon
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .processing)
        }

        // The transcription result will come through the completion handler
        print("⏳ Waiting for transcription to complete...")

        // Safety timeout: if state is still .processing after 10 seconds, force reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            if case .processing = self.appState.recordingState {
                print("⚠️ Safety timeout: state still .processing after 10s — forcing reset to .idle")
                self.appState.recordingState = .idle
                self.transcriptionEngine.cancelTranscription()
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let statusBar = appDelegate.statusBarController {
                    statusBar.updateIcon(for: .idle)
                }
                self.notificationManager.showNotification(
                    title: "Transcription Timeout",
                    body: "Transcription took too long. Please try a shorter recording or check your settings.",
                    sound: false
                )
            }
        }
    }

    func toggleDictation() {
        if appState.recordingState == .recording {
            // Check if using cloud model to call appropriate stop method
            if let currentModel = modelManager.currentModel, currentModel.category == .cloud {
                stopCloudRecording()
            } else {
                stopDictation()
            }
        } else if appState.recordingState == .idle {
            startDictation()
        } else if case .loadingModel(let modelName) = appState.recordingState {
            // User tried to start recording while model is loading
            print("⚠️ Model is still loading, please wait...")
            notificationManager.showNotification(
                title: "Please Wait",
                body: "\(modelName) is still loading...",
                sound: false
            )
        }
    }

    private func canStartDictation() -> Bool {
        // Check license or trial
        if !licenseManager.canUsePremiumFeatures() {
            showTrialExpiredAlert()
            return false
        }

        // Increment trial usage
        if !licenseManager.isLicensed {
            licenseManager.incrementTrialUsage()
        }

        // Check microphone permission
        if !permissionsManager.hasMicrophonePermission {
            print("❌ Microphone permission required")
            permissionsManager.requestMicrophonePermission { granted in
                if granted {
                    print("✓ Microphone permission granted, ready to record")
                }
            }
            return false
        }

        // Note: Accessibility permission is only needed for text insertion (Phase 4)
        // For Phase 2, we just copy to clipboard, so we can proceed without it
        if !permissionsManager.hasAccessibilityPermission {
            print("⚠️ Accessibility permission not granted - will copy to clipboard instead")
        }

        // Check transcription engine availability
        if transcriptionEngine.authorizationStatus != .authorized {
            print("⚠️ Speech recognition not authorized - requesting permission")
            transcriptionEngine.requestAuthorization { granted in
                if granted {
                    print("✓ Speech recognition authorized")
                } else {
                    print("❌ Speech recognition denied")
                }
            }
            // Can still proceed - will show error during transcription if denied
        }

        return true
    }

    // MARK: - Transcription

    private func handleWhisperResult(_ result: Result<String, WhisperEngine.WhisperError>) {
        let recordingDuration = audioManager.getRecordingDuration()

        // Dismiss processing notification
        notificationManager.dismissProcessingNotification()

        switch result {
        case .success(let transcribedText):
            print("✅ Whisper transcription successful: \(transcribedText)")

            self.errorLogger.logInfo("Whisper transcription successful", category: "Transcription", context: [
                "wordCount": "\(transcribedText.split(separator: " ").count)",
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s",
                "model": self.modelManager.currentModel?.name ?? "unknown"
            ])

            // Process and insert text (same as Apple Speech)
            processAndInsertText(transcribedText, recordingDuration: recordingDuration)

        case .failure(let error):
            print("❌ Whisper transcription failed: \(error)")

            self.errorLogger.logError(error, category: "Transcription", context: [
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s",
                "model": self.modelManager.currentModel?.name ?? "unknown"
            ])

            handleTranscriptionError(error.localizedDescription)
        }
    }

    private func handleTranscriptionResult(_ result: Result<String, TranscriptionEngine.TranscriptionError>) {
        let recordingDuration = audioManager.getRecordingDuration()

        // Dismiss processing notification
        notificationManager.dismissProcessingNotification()

        switch result {
        case .success(let transcribedText):
            print("✅ Apple Speech transcription successful: \(transcribedText)")

            self.errorLogger.logInfo("Apple Speech transcription successful", category: "Transcription", context: [
                "wordCount": "\(transcribedText.split(separator: " ").count)",
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s"
            ])

            // Process and insert text
            processAndInsertText(transcribedText, recordingDuration: recordingDuration)

        case .failure(let error):
            print("❌ Apple Speech transcription failed: \(error)")

            self.errorLogger.logError(error, category: "Transcription", context: [
                "recordingDuration": "\(String(format: "%.2f", recordingDuration))s"
            ])

            handleTranscriptionError(error.localizedDescription)
        }
    }

    private func processAndInsertText(_ transcribedText: String, recordingDuration: TimeInterval) {
        // Validate transcription - detect silence/hallucinations
        if isLikelyHallucination(transcribedText, recordingDuration: recordingDuration) {
            print("⚠️ Detected likely hallucination or silence, not inserting text: '\(transcribedText)'")

            // Show a subtle notification
            self.notificationManager.showNotification(
                title: "No Speech Detected",
                body: "No clear speech was detected in the recording.",
                sound: false
            )

            // Reset state
            self.appState.recordingState = .idle

            // Update status bar
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let statusBar = appDelegate.statusBarController {
                statusBar.updateIcon(for: .idle)
            }

            return
        }

        // Apply text processing
        let processedText = self.processTranscription(transcribedText)

        // Phase 6D: Trigger Word Detection — scan before AI enhancement
        let triggerResult = AIEnhancementEngine.shared.detectTriggerWords(in: processedText)
        let textForEnhancement = triggerResult.cleanedTranscript
        let shouldEnhance = settings.aiEnhancementEnabled || triggerResult.shouldForceAI
        let overridePrompt = triggerResult.overridePrompt

        if let matched = triggerResult.matchedRule {
            print("🎯 Trigger word matched: \"\(matched.triggerPhrase)\" → using custom prompt")
        }

        // Phase 6A: AI Enhancement (if enabled or trigger word forces it)
        if shouldEnhance {
            print("🎨 AI Enhancement active\(triggerResult.shouldForceAI ? " (triggered by keyword)" : ""), enhancing transcription...")

            // Get appropriate API key based on selected model
            let modelString = settings.selectedEnhancementModel
            guard let model = AIEnhancementEngine.EnhancementModel(rawValue: modelString) else {
                print("⚠️ Invalid enhancement model: \(modelString)")
                insertTextWithAutoSend(textForEnhancement, recordingDuration: recordingDuration)
                return
            }

            let apiKey: String
            switch model.provider {
            case .openai:
                apiKey = settings.openaiAPIKey
            case .anthropic:
                apiKey = settings.claudeAPIKey
            }

            guard !apiKey.isEmpty else {
                print("⚠️ No API key configured for AI enhancement")
                notificationManager.showNotification(
                    title: "AI Enhancement Disabled",
                    body: "Please add your API key in Settings > Advanced > AI Enhancement",
                    sound: false
                )
                insertTextWithAutoSend(textForEnhancement, recordingDuration: recordingDuration)
                return
            }

            // Get dictionary context if available
            let dictionaryContext = DictionaryManager.shared.correctSpellings.map { $0.word }.joined(separator: ", ")

            // Determine which prompt to use: trigger word prompt overrides custom/default
            let promptToUse = overridePrompt ?? (settings.customEnhancementPrompt.isEmpty ? nil : settings.customEnhancementPrompt)

            // Enhance asynchronously
            Task {
                do {
                    let enhanced = try await AIEnhancementEngine.shared.enhance(
                        textForEnhancement,
                        using: model,
                        apiKey: apiKey,
                        customPrompt: promptToUse,
                        dictionaryContext: dictionaryContext.isEmpty ? nil : dictionaryContext,
                        screenContext: self.currentScreenContext
                    )

                    await MainActor.run {
                        print("✅ AI Enhancement successful")
                        self.insertTextWithAutoSend(enhanced, recordingDuration: recordingDuration)
                    }
                } catch {
                    await MainActor.run {
                        print("❌ AI Enhancement failed: \(error.localizedDescription)")
                        self.notificationManager.showNotification(
                            title: "Enhancement Failed",
                            body: "Using original transcription. Error: \(error.localizedDescription)",
                            sound: false
                        )
                        self.insertTextWithAutoSend(textForEnhancement, recordingDuration: recordingDuration)
                    }
                }
            }
            return
        }

        // No AI enhancement, insert directly
        insertTextWithAutoSend(textForEnhancement, recordingDuration: recordingDuration)
    }

    // Phase 6A: Insert text with optional auto-send
    private func insertTextWithAutoSend(_ processedText: String, recordingDuration: TimeInterval) {
        let wordCount = processedText.split(separator: " ").count

        // Save audio file for retention
        var savedAudioPath: String? = nil
        if let audioData = self.lastRecordedAudioData, !audioData.isEmpty {
            let fileId = UUID()
            savedAudioPath = TranscriptionHistoryManager.shared.saveAudioFile(data: audioData, id: fileId)
            self.lastRecordedAudioData = nil // Clear after saving
        }

        // Add to history (with audio file path if saved)
        TranscriptionHistoryManager.shared.addTranscription(processedText, duration: recordingDuration, audioFilePath: savedAudioPath)

        // Insert text directly with performance monitoring
        PerformanceMonitor.shared.startTextInsertion()

        self.textInsertionManager.insertText(processedText) { result in
            PerformanceMonitor.shared.endTextInsertion()

            switch result {
            case .success:
                self.errorLogger.logInfo("Text inserted directly", category: "TextInsertion")

                // Phase 6A: Auto-Send After Paste (if enabled)
                if AutoSendService.shared.shouldTriggerAutoSend() {
                    print("📤 Auto-send enabled for this app, sending...")
                    AutoSendService.shared.sendAfterDelay(0.2) // 200ms delay
                }

            case .failure(let error):
                self.errorLogger.logWarning(error.localizedDescription, category: "TextInsertion")
                // Fallback to clipboard is already handled in TextInsertionManager
            }

            // Complete performance monitoring session
            PerformanceMonitor.shared.completeSession()
        }

        // Record analytics
        self.analyticsManager.recordTranscription(
            duration: recordingDuration,
            wordCount: wordCount,
            transcriptionTime: recordingDuration
        )

        // Record statistics
        self.recordTranscription(text: processedText)

        // Reset state
        self.appState.recordingState = .idle

        // Update status bar
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .idle)
        }

        // Show success notification
        self.notificationManager.showTranscriptionSuccess(
            text: processedText,
            wordCount: wordCount,
            duration: recordingDuration
        )
    }

    private func handleTranscriptionError(_ errorMessage: String) {
        // Record error in analytics
        self.analyticsManager.recordError(type: "Transcription", context: errorMessage)

        self.appState.recordingState = .error(errorMessage)

        // Reset state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.appState.recordingState = .idle
        }

        // Update status bar
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .idle)
        }

        // Show error notification
        self.notificationManager.showTranscriptionError(error: errorMessage)
    }

    private func isLikelyHallucination(_ text: String, recordingDuration: TimeInterval) -> Bool {
        // Trim whitespace
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check 1: Empty or very short text
        if trimmed.count < 3 {
            return true
        }

        // Check 2: Recording was too short (less than 0.3 seconds)
        // Likely just noise or accidental trigger
        if recordingDuration < 0.3 {
            return true
        }

        // Check 3: Common hallucination phrases that AI models generate for silence
        let commonHallucinations = [
            "thank you",
            "thanks",
            "thank you.",
            "thanks.",
            "bye",
            "bye.",
            "goodbye",
            "goodbye.",
            "you",
            "thank",
            "thanks for watching",
            "thanks for watching.",
            "see you next time",
            "see you next time.",
            "...",
            ".",
            ". ."
        ]

        // Check if text matches any hallucination pattern
        if commonHallucinations.contains(trimmed) {
            return true
        }

        // Check 4: Very short recordings with generic single words
        if recordingDuration < 1.0 && trimmed.split(separator: " ").count == 1 {
            // Single word in very short recording is suspicious
            let shortWords = ["the", "a", "an", "i", "you", "ok", "okay", "um", "uh", "ah"]
            if shortWords.contains(trimmed) {
                return true
            }
        }

        // Looks legitimate
        return false
    }

    private func processTranscription(_ text: String) -> String {
        var processed = text

        // Apply settings
        if settings.autoPunctuation {
            // Already handled by Speech framework
        }

        if settings.smartCapitalization {
            // Already handled by Speech framework
        }

        if settings.insertSpaceAfterText {
            processed += " "
        }

        return processed
    }

    private func showTrialExpiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Trial Expired"
        alert.alertStyle = .informational

        #if APPSTORE
            // App Store build: Show in-app purchase option
            alert.informativeText = "Your 7-day trial has expired. Upgrade to Pro to continue using EchoTune with unlimited transcriptions."
            alert.addButton(withTitle: "Upgrade to Pro")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Show in-app purchase view
                DispatchQueue.main.async {
                    self.showPurchaseSheet = true
                }
            }
        #else
            // Direct sale build: Show license key option
            alert.informativeText = "Your 7-day trial has expired. Please purchase a license to continue using EchoTune."
            alert.addButton(withTitle: "Enter License Key")
            alert.addButton(withTitle: "Purchase Online")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open license sheet directly
                DispatchQueue.main.async {
                    self.showLicenseSheet = true
                }
            } else if response == .alertSecondButtonReturn {
                // Open website purchase page
                if let url = URL(string: "https://echotune.app/purchase") {
                    NSWorkspace.shared.open(url)
                }
            }
        #endif
    }

    // MARK: - Re-Transcription

    /// Re-transcribe a saved audio file with the currently selected model
    func retranscribe(historyItem: TranscriptionHistoryItem, completion: @escaping (String?) -> Void) {
        guard let audioPath = historyItem.audioFilePath,
              FileManager.default.fileExists(atPath: audioPath) else {
            print("❌ Audio file not found for re-transcription")
            completion(nil)
            return
        }

        guard let currentModel = modelManager.currentModel else {
            print("❌ No model selected for re-transcription")
            notificationManager.showNotification(
                title: "Re-Transcription Failed",
                body: "Please select a transcription model first.",
                sound: false
            )
            completion(nil)
            return
        }

        print("🔄 Re-transcribing with model: \(currentModel.name)")

        // Read audio data from file
        guard let audioData = try? Data(contentsOf: URL(fileURLWithPath: audioPath)) else {
            print("❌ Failed to read audio file")
            completion(nil)
            return
        }

        // Route to appropriate transcription service
        if currentModel.category == .cloud {
            Task {
                do {
                    let transcribedText: String

                    if currentModel.id.contains("groq") || currentModel.name.lowercased().contains("groq") {
                        let apiKey = settings.groqAPIKey
                        guard !apiKey.isEmpty else {
                            await MainActor.run { completion(nil) }
                            return
                        }
                        transcribedText = try await GroqTranscriptionService.shared.transcribe(
                            audioData: audioData,
                            language: settings.preferredLanguage.components(separatedBy: "-").first,
                            apiKey: apiKey
                        )
                    } else if currentModel.id.contains("deepgram") || currentModel.name.lowercased().contains("deepgram") {
                        let apiKey = settings.deepgramAPIKey
                        guard !apiKey.isEmpty else {
                            await MainActor.run { completion(nil) }
                            return
                        }
                        transcribedText = try await DeepgramTranscriptionService.shared.transcribeToText(
                            audioData: audioData,
                            model: .nova,
                            language: settings.preferredLanguage.components(separatedBy: "-").first,
                            apiKey: apiKey
                        )
                    } else {
                        await MainActor.run { completion(nil) }
                        return
                    }

                    await MainActor.run {
                        print("✅ Re-transcription successful: \(transcribedText.prefix(50))...")
                        notificationManager.showNotification(
                            title: "Re-Transcription Complete",
                            body: "Transcription updated with \(currentModel.name).",
                            sound: false
                        )
                        completion(transcribedText)
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Re-transcription failed: \(error)")
                        notificationManager.showNotification(
                            title: "Re-Transcription Failed",
                            body: error.localizedDescription,
                            sound: false
                        )
                        completion(nil)
                    }
                }
            }
        } else {
            // For local Whisper models, load and transcribe
            if currentModel.category == .local && !currentModel.isBuiltIn {
                // Load model if needed
                if !whisperEngine.isAvailable || whisperEngine.loadedModelName != currentModel.name {
                    whisperEngine.loadModel(currentModel) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success:
                            self.whisperEngine.transcribeAudio(audioData) { result in
                                switch result {
                                case .success(let text):
                                    print("✅ Re-transcription (Whisper) successful")
                                    self.notificationManager.showNotification(
                                        title: "Re-Transcription Complete",
                                        body: "Transcription updated with \(currentModel.name).",
                                        sound: false
                                    )
                                    completion(text)
                                case .failure(let error):
                                    print("❌ Re-transcription failed: \(error)")
                                    self.notificationManager.showNotification(
                                        title: "Re-Transcription Failed",
                                        body: error.localizedDescription,
                                        sound: false
                                    )
                                    completion(nil)
                                }
                            }
                        case .failure(let error):
                            print("❌ Failed to load model for re-transcription: \(error)")
                            self.notificationManager.showNotification(
                                title: "Re-Transcription Failed",
                                body: "Failed to load model: \(error.localizedDescription)",
                                sound: false
                            )
                            completion(nil)
                        }
                    }
                } else {
                    whisperEngine.transcribeAudio(audioData) { [weak self] result in
                        switch result {
                        case .success(let text):
                            print("✅ Re-transcription (Whisper) successful")
                            self?.notificationManager.showNotification(
                                title: "Re-Transcription Complete",
                                body: "Transcription updated with \(currentModel.name).",
                                sound: false
                            )
                            completion(text)
                        case .failure(let error):
                            print("❌ Re-transcription failed: \(error)")
                            self?.notificationManager.showNotification(
                                title: "Re-Transcription Failed",
                                body: error.localizedDescription,
                                sound: false
                            )
                            completion(nil)
                        }
                    }
                }
            } else {
                // Built-in Apple Speech — use audio data transcription
                transcriptionEngine.transcribeAudio(audioData) { [weak self] result in
                    switch result {
                    case .success(let text):
                        print("✅ Re-transcription (Apple Speech) successful")
                        self?.notificationManager.showNotification(
                            title: "Re-Transcription Complete",
                            body: "Transcription updated with Apple Speech.",
                            sound: false
                        )
                        completion(text)
                    case .failure(let error):
                        print("❌ Re-transcription failed: \(error)")
                        self?.notificationManager.showNotification(
                            title: "Re-Transcription Failed",
                            body: error.localizedDescription,
                            sound: false
                        )
                        completion(nil)
                    }
                }
            }
        }
    }

    // MARK: - Statistics

    func recordTranscription(text: String) {
        let wordCount = text.split(separator: " ").count
        appState.incrementTranscriptionCount(wordCount: wordCount)
        print("📊 Recorded transcription: \(wordCount) words")
    }

    // MARK: - UI Helpers

    private func showErrorAlert(message: String) {
        errorLogger.logError(
            NSError(domain: "com.echotune.app", code: -1, userInfo: [NSLocalizedDescriptionKey: message]),
            category: "Recording",
            context: [:]
        )

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Recording Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
