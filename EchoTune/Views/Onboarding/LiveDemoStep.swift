//
//  LiveDemoStep.swift
//  EchoTune
//
//  Onboarding Step 4: Live Demo (THE WOW MOMENT)
//

import SwiftUI

struct LiveDemoStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared

    @State private var appeared = false
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var displayedText = ""
    @State private var resultCaption = ""
    @State private var resultIsError = false
    @State private var isTranscribing = false
    @State private var showResult = false
    @State private var recordingSeconds: Int = 0
    @State private var recordingTimer: Timer?
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.05, count: 30)
    @State private var audioLevelTimer: Timer?
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)

            Spacer().frame(height: 8)

            Text("Try it now")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 6)

            Text(isRecording ? "Listening\u{2026} speak naturally" : (showResult ? "See? That's EchoTune." : "Tap the button and say something!"))
                .font(.system(size: 14))
                .foregroundColor(isRecording ? .echoPrimary : .echoTextSecondary)
                .animation(.easeInOut(duration: 0.3), value: isRecording)
                .animation(.easeInOut(duration: 0.3), value: showResult)

            Spacer().frame(height: 32)

            if showResult {
                // Transcribed text result with typing effect
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.echoSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke((resultIsError ? Color.red : Color.echoPrimary).opacity(0.3), lineWidth: 1)
                            )

                        VStack(spacing: 12) {
                            Image(systemName: resultIsError ? "exclamationmark.triangle.fill" : "text.quote")
                                .font(.system(size: 20))
                                .foregroundColor(resultIsError ? .red : .echoPrimary)

                            Text(displayedText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.echoTextPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .frame(minHeight: 60)

                            if displayedText.count == transcribedText.count && !resultCaption.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: resultIsError ? "info.circle" : "sparkles")
                                        .font(.system(size: 11))
                                    Text(resultCaption)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(resultIsError ? .red : .echoPrimary)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding(.vertical, 24)
                    }
                    .frame(maxWidth: 440)
                    .frame(minHeight: 140)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Try again button
                    Button(action: resetDemo) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                            Text("Try Again")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.echoTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 48)
            } else {
                // Recording visualizer area
                VStack(spacing: 24) {
                    if isRecording {
                        // Audio waveform visualization
                        AudioLevelWaveform(levels: audioLevels)
                            .frame(height: 60)
                            .frame(maxWidth: 300)
                            .transition(.opacity)

                        Text("\(recordingSeconds)s")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.echoTextTertiary)
                    } else if isTranscribing {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.echoPrimary)

                        Text("Transcribing\u{2026}")
                            .font(.system(size: 13))
                            .foregroundColor(.echoTextSecondary)
                    } else {
                        // Placeholder encouragement
                        Text("\u{1F3A4}")
                            .font(.system(size: 40))
                            .opacity(0.6)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 48)
            }

            Spacer().frame(height: 28)

            // Big record button (only show when not displaying result)
            if !showResult {
                Button(action: toggleRecording) {
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .stroke(Color.echoPrimary.opacity(isRecording ? 0.3 : 0), lineWidth: 3)
                            .frame(width: 88, height: 88)
                            .scaleEffect(pulseScale)

                        // Button background
                        Circle()
                            .fill(
                                isRecording
                                    ? LinearGradient(colors: [Color.red, Color.red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.echoPrimary, Color.echoAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: (isRecording ? Color.red : Color.echoPrimary).opacity(0.4), radius: 16, y: 6)

                        // Icon
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTranscribing)
            }

            Spacer()

            // Continue
            PrimaryButton(title: "Continue", action: onNext)
                .opacity(appeared ? 1 : 0)

            if !showResult {
                Text("You can skip this \u{2014} but the wow moment is worth it!")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
                    .padding(.top, 6)
            }

            Spacer().frame(height: 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .onDisappear {
            stopEverything()
        }
    }

    // MARK: - Recording Logic

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard let currentModel = currentModel else {
            presentDemoMessage(
                "No transcription model is selected. Go back to Setup and choose an offline model before running the demo.",
                isError: true,
                caption: "Setup required"
            )
            return
        }

        guard currentModel.category != .cloud else {
            presentDemoMessage(
                "The onboarding demo only supports Apple Speech or an offline Whisper model. Go back to Setup and install the Base model for a local demo.",
                isError: true,
                caption: "Cloud models need API keys"
            )
            return
        }

        if currentModel.isBuiltIn && !transcriptionEngine.isPermissionGranted {
            transcriptionEngine.requestPermission { granted in
                if granted {
                    self.beginRecording()
                } else {
                    self.presentDemoMessage(
                        "Speech Recognition permission is required when Apple Speech is selected. Allow it in the system prompt, or go back and install the offline Base model instead.",
                        isError: true,
                        caption: "Permission required"
                    )
                }
            }
            return
        }

        beginRecording()
    }

    private func beginRecording() {
        isRecording = true
        recordingSeconds = 0
        transcribedText = ""
        displayedText = ""
        resultCaption = ""
        resultIsError = false
        showResult = false

        // Start audio recording
        audioManager.startRecording()

        // Timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingSeconds += 1
            // Auto-stop after 15 seconds
            if recordingSeconds >= 15 {
                stopRecording()
            }
        }

        // Audio level monitoring
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            let level = CGFloat(audioManager.audioLevel)
            withAnimation(.easeOut(duration: 0.06)) {
                audioLevels.removeFirst()
                audioLevels.append(max(0.05, level * 12))
            }
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }

    private func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        audioLevelTimer?.invalidate()

        withAnimation { pulseScale = 1.0 }

        isTranscribing = true

        // Determine engine type
        let useWhisper = currentModel?.category == .local && currentModel?.isBuiltIn == false
        let engineType: AudioManager.AudioEngine = useWhisper ? .whisper : .appleSpeech
        let audioData = audioManager.stopRecording(forEngine: engineType)

        if let audioData = audioData, !audioData.isEmpty {
            performDemoTranscription(audioData: audioData)
        } else {
            isTranscribing = false
            presentDemoMessage(
                "No audio was captured. Check the selected microphone, then try again and speak a little louder.",
                isError: true,
                caption: "Recording failed"
            )
        }
    }

    private func performDemoTranscription(audioData: Data) {
        guard let currentModel = currentModel else {
            isTranscribing = false
            presentDemoMessage(
                "No transcription model is selected. Go back to Setup and choose a model before running the demo.",
                isError: true,
                caption: "Setup required"
            )
            return
        }

        if currentModel.isBuiltIn {
            transcriptionEngine.transcribeAudio(audioData) { result in
                DispatchQueue.main.async {
                    self.isTranscribing = false

                    switch result {
                    case .success(let text):
                        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if cleanedText.isEmpty {
                            self.presentDemoMessage(
                                "No words were detected. Try again, speak naturally, and stay close to the microphone.",
                                isError: true,
                                caption: "Nothing recognized"
                            )
                        } else {
                            self.presentDemoMessage(
                                cleanedText,
                                isError: false,
                                caption: "Processed with Apple Speech"
                            )
                        }
                    case .failure(let error):
                        self.presentDemoMessage(
                            self.appleSpeechErrorMessage(for: error),
                            isError: true,
                            caption: "Apple Speech could not complete the demo"
                        )
                    }
                }
            }
            return
        }

        guard let installedModel = modelManager.installedModel(withID: currentModel.id),
              modelManager.isInstalledAndUsable(currentModel) else {
            isTranscribing = false
            presentDemoMessage(
                "The selected offline model is not installed anymore. Go back to Setup and download the Base model again.",
                isError: true,
                caption: "Offline model missing"
            )
            return
        }

        guard modelManager.setCurrentModel(installedModel) else {
            isTranscribing = false
            presentDemoMessage(
                "EchoTune could not switch to \(installedModel.name). Go back to Setup and re-run model setup.",
                isError: true,
                caption: "Model selection failed"
            )
            return
        }

        WhisperEngine.shared.loadModel(installedModel) { loadResult in
            DispatchQueue.main.async {
                switch loadResult {
                case .success:
                    WhisperEngine.shared.transcribeAudio(audioData) { result in
                        DispatchQueue.main.async {
                            self.isTranscribing = false

                            switch result {
                            case .success(let transcription):
                                let cleanedText = transcription.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if cleanedText.isEmpty {
                                    self.presentDemoMessage(
                                        "No words were detected. Try again with a longer phrase and a quieter room if possible.",
                                        isError: true,
                                        caption: "Nothing recognized"
                                    )
                                } else {
                                    self.presentDemoMessage(
                                        cleanedText,
                                        isError: false,
                                        caption: "Processed with \(installedModel.name)"
                                    )
                                }
                            case .failure(let error):
                                self.presentDemoMessage(
                                    self.whisperErrorMessage(for: error, model: installedModel),
                                    isError: true,
                                    caption: "Offline transcription failed"
                                )
                            }
                        }
                    }
                case .failure(let error):
                    self.isTranscribing = false
                    self.presentDemoMessage(
                        "EchoTune downloaded \(installedModel.name), but Whisper could not load it for the demo: \(error.localizedDescription)",
                        isError: true,
                        caption: "Model load failed"
                    )
                }
            }
        }
    }

    private func showResultWithAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showResult = true
        }

        // Typing animation
        let chars = Array(transcribedText)
        for (index, _) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.025) {
                displayedText = String(chars.prefix(index + 1))
            }
        }
    }

    private func resetDemo() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showResult = false
            transcribedText = ""
            displayedText = ""
            resultCaption = ""
            resultIsError = false
            audioLevels = Array(repeating: 0.05, count: 30)
        }
    }

    private func stopEverything() {
        recordingTimer?.invalidate()
        audioLevelTimer?.invalidate()
        if isRecording {
            _ = audioManager.stopRecording()
        }
    }

    private var currentModel: AIModel? {
        modelManager.currentModel ?? modelManager.availableModels.first(where: { $0.id == "apple-speech" })
    }

    private func presentDemoMessage(_ message: String, isError: Bool, caption: String) {
        transcribedText = message
        displayedText = ""
        resultIsError = isError
        resultCaption = caption
        showResultWithAnimation()
    }

    private func appleSpeechErrorMessage(for error: TranscriptionEngine.TranscriptionError) -> String {
        switch error {
        case .permissionDenied:
            return "Speech Recognition permission is not granted. Allow it in System Settings, or use the offline Base model instead."
        case .unavailable:
            return "Apple Speech is unavailable right now on this Mac. Go back to Setup and use the offline Base model for a deterministic demo."
        case .noAudioData:
            return "No audio data reached the speech recognizer. Check the selected microphone and try again."
        case .recognitionError(let underlyingError):
            return "Apple Speech failed during transcription: \(underlyingError.localizedDescription)"
        case .audioFormatError:
            return "EchoTune could not prepare the recorded audio for Apple Speech. Try the demo again."
        case .processingError:
            return "Apple Speech could not finish processing that sample. Try again with a slightly longer phrase."
        }
    }

    private func whisperErrorMessage(for error: WhisperEngine.WhisperError, model: AIModel) -> String {
        switch error {
        case .modelNotLoaded:
            return "\(model.name) was not loaded when transcription started. Go back to Setup and re-run model setup."
        case .modelLoadFailed(let underlyingError):
            return "Whisper could not load \(model.name): \(underlyingError.localizedDescription)"
        case .transcriptionFailed(let underlyingError):
            return "Whisper failed to transcribe the recording: \(underlyingError.localizedDescription)"
        case .audioFormatError:
            return "EchoTune could not convert the recorded audio into Whisper's expected format."
        case .noAudioData:
            return "No audio data reached Whisper. Check the selected microphone and try again."
        case .modelNotFound:
            return "\(model.name) is no longer installed on this Mac. Go back to Setup and download it again."
        }
    }
}
