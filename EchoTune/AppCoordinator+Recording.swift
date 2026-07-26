//
//  AppCoordinator+Recording.swift
//  EchoTune
//
//  Dictation start/stop, recording logic, cloud recording, and toggle.
//

import Foundation
import AppKit
import AVFAudio
import Speech
import os.log

// MARK: - Recording & Dictation

extension AppCoordinator {

    // MARK: - Dictation Actions (Phase 2: Real implementation!)

    func startDictation() {
        debugLog("🎤 Start dictation")
        os_log("🎤 startDictation called", log: appLog, type: .info)

        // Check if we can start
        guard canStartDictation() else {
            debugLog("❌ Cannot start dictation - requirements not met")
            os_log("❌ canStartDictation returned false", log: appLog, type: .error)
            return
        }

        // Context detection runs off the main thread so recording starts without delay.
        DispatchQueue.global(qos: .userInitiated).async {
            // Detect and apply Power Mode (context-aware configuration)
            PowerModeManager.shared.detectAndApplyPowerMode()
        }

        // Get current model
        guard let currentModel = modelManager.currentModel else {
            debugLog("❌ No model selected")
            os_log("❌ No model selected", log: appLog, type: .error)
            showErrorAlert(message: "Please select a transcription model in AI Models settings")
            return
        }

        // Notify user about dynamic fallback to Apple Speech if a local Whisper model is selected but not installed
        let isWhisperPreferred = currentModel.category == .local && !currentModel.isBuiltIn
        if isWhisperPreferred && !modelManager.isInstalledAndUsable(currentModel) {
            os_log("⚠️ Local Whisper model %{public}@ is selected but not installed/usable on disk. Falling back to Apple Speech.", log: appLog, type: .error, currentModel.name)
            debugLog("⚠️ Local Whisper model \(currentModel.name) is missing from disk. Dynamic fallback to Apple Speech.")
            
            notificationManager.showNotification(
                title: "Using Apple Speech",
                body: "\(currentModel.name) is not downloaded. Falling back to Apple Speech.",
                sound: false
            )
        }

        debugLog("📍 Using model: \(currentModel.name) (Whisper: \(useWhisper))")
        os_log("📍 Model: %{public}@ category=%{public}@ isBuiltIn=%d useWhisper=%d", log: appLog, type: .info, currentModel.name, currentModel.category.rawValue, currentModel.isBuiltIn ? 1 : 0, useWhisper ? 1 : 0)

        // Load Whisper model if needed
        if useWhisper {
            if !whisperEngine.isAvailable || whisperEngine.loadedModelName != currentModel.name {
                debugLog("📦 Loading Whisper model: \(currentModel.name)")

                // Show loading state
                appState.recordingState = .loadingModel(currentModel.name)

                // Update status bar to show loading
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let statusBar = appDelegate.statusBarController {
                    statusBar.updateIcon(for: .loadingModel(currentModel.name))
                }

                // Show notification to user
                notificationManager.showNotification(
                    title: "Setting Up Model (One-Time)",
                    body: "Compiling \(currentModel.name) for your Mac — this takes 1-3 minutes the first time only. Future use will be instant.",
                    sound: false
                )

                whisperEngine.loadModel(currentModel) { [weak self] result in
                    guard let self = self else { return }

                    // Dismiss loading notification
                    self.notificationManager.dismissProcessingNotification()

                    switch result {
                    case .success:
                        debugLog("✅ Whisper model loaded, starting dictation")

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
                        debugLog("❌ Failed to load Whisper model: \(error)")

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

    func beginCloudRecording(model: AIModel) {
        os_log("☁️ beginCloudRecording: %{public}@ (id=%{public}@)", log: appLog, type: .info, model.name, model.id)
        startRecordingAudit(for: model)

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
        debugLog("✓ Cloud recording started for: \(model.name)")

        // Update status bar icon
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .recording)
        }
    }

    func stopCloudRecording() {
        os_log("🛑 stopCloudRecording called", log: appLog, type: .info)

        // Play stop sound (if enabled)
        SoundManager.shared.playStopSound()

        // Update state
        appState.recordingState = .processing

        // Hide recording indicator (all styles)
        hideRecorderUI()

        // Restore system output first — must happen even if capturing failed,
        // or a failed stop leaves the user's Mac muted permanently.
        if didMuteSystemOutput {
            SystemAudioManager.shared.restoreSystemOutput()
            didMuteSystemOutput = false
        }

        // Stop audio recording and get audio data as proper WAV for cloud services
        let engineType: AudioManager.AudioEngine = .cloud
        guard let audioData = audioManager.stopRecording(forEngine: engineType) else {
            os_log("❌ stopRecording returned nil", log: appLog, type: .error)
            handleTranscriptionError("Failed to capture audio data")
            return
        }

        // Store audio data for retention
        self.lastRecordedAudioData = audioData

        os_log("📊 Captured %d bytes for cloud transcription", log: appLog, type: .info, audioData.count)
        currentProcessingMetadata.audioByteCount = audioData.count

        let recordingDuration = audioManager.lastRecordingDuration
        PerformanceMonitor.shared.endRecording(
            duration: recordingDuration,
            bufferCount: 0
        )

        // (System output already restored above, before the capture guard.)

        // VAD: Check if there's significant speech
        if VADManager.shared.config.enabled {
            let hasSignificantSpeech = audioManager.hasSignificantSpeech()
            if !hasSignificantSpeech {
                debugLog("⚠️ No significant speech detected - skipping cloud transcription")
                notificationManager.showNotification(
                    title: "No Speech Detected",
                    body: "The recording didn't contain any clear speech. Please try again.",
                    sound: false
                )
                appState.recordingState = .idle
                appState.recordingStatusDetail = nil
                clearCurrentProcessingState()
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
                            handleTranscriptionError("Cloud transcription API key not configured. Add a Groq (gsk_…) or xAI Grok (xai-…) key in Settings > API Keys.")
                        }
                        return
                    }

                    let providerName = GroqTranscriptionService.providerDisplayName(for: apiKey)
                    let transcriptionModelName = providerName == "Groq" ? "whisper-large-v3-turbo" : "stt"

                    os_log("☁️ Transcribing with %{public}@... audioSize=%d apiKeyLen=%d", log: appLog, type: .info, providerName, audioData.count, apiKey.count)
                    beginTranscriptionAudit(provider: providerName, model: transcriptionModelName, detail: "Uploading audio to \(providerName)...")
                    PerformanceMonitor.shared.startTranscription(engine: providerName, model: transcriptionModelName)
                    transcribedText = try await GroqTranscriptionService.shared.transcribe(
                        audioData: audioData,
                        language: AppSettings.shared.autoDetectLanguage ? nil : settings.preferredLanguage.components(separatedBy: "-").first,
                        apiKey: apiKey
                    )
                    os_log("✅ %{public}@ returned: '%@'", log: appLog, type: .info, providerName, transcribedText)

                } else if currentModel.id.contains("deepgram") || currentModel.name.lowercased().contains("deepgram") {
                    // Use Deepgram
                    let apiKey = settings.deepgramAPIKey
                    guard !apiKey.isEmpty else {
                        await MainActor.run {
                            handleTranscriptionError("Deepgram API key not configured. Please add your API key in Settings > API Keys.")
                        }
                        return
                    }

                    debugLog("☁️ Transcribing with Deepgram...")
                    beginTranscriptionAudit(provider: "Deepgram", model: "nova-2", detail: "Uploading audio to Deepgram...")
                    PerformanceMonitor.shared.startTranscription(engine: "Deepgram", model: "nova-2")
                    transcribedText = try await DeepgramTranscriptionService.shared.transcribeToText(
                        audioData: audioData,
                        model: .nova,
                        language: AppSettings.shared.autoDetectLanguage ? nil : settings.preferredLanguage.components(separatedBy: "-").first,
                        apiKey: apiKey
                    )

                } else {
                    await MainActor.run {
                        handleTranscriptionError("Unknown cloud model: \(currentModel.name)")
                    }
                    return
                }

                await MainActor.run {
                    self.completeTranscriptionAudit()
                    PerformanceMonitor.shared.endTranscription(wordCount: transcribedText.split(separator: " ").count)

                    debugLog("✅ Cloud transcription successful: \(transcribedText)")
                    self.errorLogger.logInfo("Cloud transcription successful", category: "Transcription", context: [
                        "wordCount": "\(transcribedText.split(separator: " ").count)",
                        "recordingDuration": "\(String(format: "%.2f", recordingDuration))s",
                        "model": currentModel.name
                    ])

                    // Process and insert text
                    self.processAndInsertText(
                        FinalizedTranscription(
                            outputText: transcribedText,
                            originalText: transcribedText,
                            translatedText: nil,
                            detectedLanguage: nil
                        ),
                        recordingDuration: recordingDuration
                    )
                }

            } catch {
                await MainActor.run {
                    os_log("❌ Cloud transcription FAILED: %{public}@", log: appLog, type: .error, "\(error)")
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

    // MARK: - Local Recording

    func beginRecording() {
        os_log("🔴 beginRecording called, useWhisper=%d", log: appLog, type: .info, useWhisper ? 1 : 0)

        if let currentModel = modelManager.currentModel {
            startRecordingAudit(for: currentModel)
        }

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
        debugLog("✓ Recording started successfully")

        // Start transcription based on selected model
        if useWhisper {
            // Whisper streaming transcription
            debugLog("🎯 Starting Whisper streaming transcription")

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
                debugLog("🎯 Starting Apple Speech live transcription")

                transcriptionEngine.startLiveTranscription(audioFormat: audioFormat) { [weak self] result in
                    guard let self = self else { return }
                    self.handleTranscriptionResult(result)
                }

                // Set up callback to stream audio buffers to Apple Speech
                audioManager.onAudioBuffer = { [weak self] buffer in
                    self?.transcriptionEngine.appendAudioBuffer(buffer)
                }
            } else {
                debugLog("⚠️ Could not get audio format, live transcription not started")
            }
        }

        // Update status bar icon
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let statusBar = appDelegate.statusBarController {
            statusBar.updateIcon(for: .recording)
        }
    }

    func stopDictation() {
        debugLog("🛑 Stop dictation")
        os_log("🛑 stopDictation called, useWhisper=%d", log: appLog, type: .info, useWhisper ? 1 : 0)

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
            debugLog("🎙️ Performing VAD analysis...")
            let hasSignificantSpeech = audioManager.hasSignificantSpeech()

            if !hasSignificantSpeech {
                debugLog("⚠️ No significant speech detected - skipping transcription")

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
                self.appState.recordingStatusDetail = nil
                self.clearCurrentProcessingState()

                // Update status bar
                if let appDelegate = NSApp.delegate as? AppDelegate,
                   let statusBar = appDelegate.statusBarController {
                    statusBar.updateIcon(for: .idle)
                }

                return  // Skip transcription entirely
            }

            // Log VAD analysis
            if let vadAnalysis = audioManager.getVADAnalysis() {
                debugLog("📊 VAD Analysis:")
                debugLog(vadAnalysis.summary)

                self.errorLogger.logInfo("VAD Analysis completed", category: "VAD", context: [
                    "speechPercentage": "\(vadAnalysis.speechPercentage)%",
                    "speechDuration": "\(vadAnalysis.speechDuration)s",
                    "segments": "\(vadAnalysis.speechSegments.count)"
                ])
            }
        }

        // End transcription based on which engine is being used
        if useWhisper {
            debugLog("🛑 Ending Whisper transcription")
            beginTranscriptionAudit(detail: "Finalising local Whisper transcript...")
            whisperEngine.endStreamingTranscription { [weak self] result in
                guard let self = self else { return }
                self.handleWhisperResult(result)
            }
        } else {
            debugLog("🛑 Ending Apple Speech transcription")
            beginTranscriptionAudit(provider: "Apple Speech", model: "Built-in", detail: "Transcribing with Apple Speech...")
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
        debugLog("⏳ Waiting for transcription to complete...")

        // Safety timeout: scale with recording duration (min 15s, max 60s)
        let safetyTimeout = max(15.0, min(60.0, recordingDuration * 2.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + safetyTimeout) { [weak self] in
            guard let self = self else { return }
            if case .processing = self.appState.recordingState {
                debugLog("⚠️ Safety timeout: state still .processing after \(safetyTimeout)s — forcing reset to .idle")
                self.appState.recordingState = .idle
                self.appState.recordingStatusDetail = nil
                self.transcriptionEngine.cancelTranscription()
                self.clearCurrentProcessingState()
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
            debugLog("⚠️ Model is still loading, please wait...")
            notificationManager.showNotification(
                title: "Please Wait",
                body: "\(modelName) is still loading...",
                sound: false
            )
        } else if case .processing = appState.recordingState {
            // User pressed toggle while transcription is still processing.
            // Force-reset to idle so the next press can start fresh.
            debugLog("⚠️ Toggle pressed during .processing — force-resetting to .idle")
            appState.recordingState = .idle
            appState.recordingStatusDetail = nil
            audioManager.onAudioBuffer = nil
            clearCurrentProcessingState()
            transcriptionEngine.cancelTranscription()
            hideRecorderUI()
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let statusBar = appDelegate.statusBarController {
                statusBar.updateIcon(for: .idle)
            }
        } else if case .error(_) = appState.recordingState {
            // User pressed toggle while in error state — reset to idle
            debugLog("⚠️ Toggle pressed during .error — resetting to .idle")
            appState.recordingState = .idle
            appState.recordingStatusDetail = nil
            clearCurrentProcessingState()
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let statusBar = appDelegate.statusBarController {
                statusBar.updateIcon(for: .idle)
            }
        }
    }

    func canStartDictation() -> Bool {
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
            debugLog("❌ Microphone permission required")
            permissionsManager.requestMicrophonePermission { granted in
                if granted {
                    debugLog("✓ Microphone permission granted, ready to record")
                }
            }
            return false
        }

        // Note: Accessibility permission is only needed for text insertion (Phase 4)
        // For Phase 2, we just copy to clipboard, so we can proceed without it
        if !permissionsManager.hasAccessibilityPermission {
            debugLog("⚠️ Accessibility permission not granted - will copy to clipboard instead")
        }

        // Only check Apple Speech Recognition authorization when using Apple Speech engine
        // WhisperKit and cloud models (Groq, etc.) don't need this permission
        if !useWhisper, let currentModel = modelManager.currentModel,
           !currentModel.id.contains("groq") && !currentModel.id.contains("deepgram") && currentModel.category != .cloud {
            if transcriptionEngine.authorizationStatus != .authorized {
                debugLog("⚠️ Speech recognition not authorized - requesting permission")
                transcriptionEngine.requestAuthorization { granted in
                    if granted {
                        debugLog("✓ Speech recognition authorized")
                    } else {
                        debugLog("❌ Speech recognition denied")
                    }
                }
                // Can still proceed - will show error during transcription if denied
            }
        }

        return true
    }

    func showTrialExpiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Trial Expired"
        alert.alertStyle = .informational

        #if APPSTORE
            // App Store build: Show in-app purchase option
            alert.informativeText = "Your 7-day trial has expired. Buy the one-time Pro unlock to continue using EchoTune with unlimited transcriptions."
            alert.addButton(withTitle: "Purchase Now")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                DispatchQueue.main.async {
                    self.presentPurchaseFlow()
                }
            }
        #else
            // Direct sale build: Show license key option
            alert.informativeText = "Your 7-day trial has expired. Purchase a one-time EchoTune license, or enter an existing license key, to continue."
            alert.addButton(withTitle: "Purchase Now")
            alert.addButton(withTitle: "Enter License Key")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                DispatchQueue.main.async {
                    self.presentPurchaseFlow()
                }
            } else if response == .alertSecondButtonReturn {
                DispatchQueue.main.async {
                    self.showLicenseSheet = true
                }
            }
        #endif
    }
}
