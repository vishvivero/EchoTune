//
//  LiveDemoStep.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import Combine

struct LiveDemoStep: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var transcriptionEngine = TranscriptionEngine.shared
    @State private var transcriptionText = ""
    @State private var transcriptionCaption = "Press record and say something."
    @State private var autoStopTimer: AnyCancellable?
    @State private var isProcessing = false
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                OnboardingTheme.HeaderIconChip(systemName: "waveform")

                Text("Try Live Dictation")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Press record and say anything — your words appear in the field below, instantly.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)

            dictationField
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                recordButton
                    .accessibilityIdentifier("onboarding.liveDemo.recordButton")

                Text(audioManager.isRecording ? "Recording… (\(AudioManager.formatDuration(audioManager.recordingDuration))) — tap to stop" : (isProcessing ? "Transcribing…" : "Tap the mic and speak"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("onboarding.liveDemo.statusLabel")
            }

            Spacer(minLength: 0)

            waveform
                .padding(.horizontal, 40)
                .frame(height: 80)

            if !transcriptionText.isEmpty && !isProcessing {
                Button(action: onNext) {
                    Text("Continue")
                        .frame(width: 200)
                }
                .buttonStyle(GradientProminentButtonStyle())
                .controlSize(.large)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .onDisappear {
            autoStopTimer?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LiveTranscriptionUpdate"))) { notification in
            if let text = notification.userInfo?["text"] as? String, !text.isEmpty {
                transcriptionText = text
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TranscriptionComplete"))) { notification in
            if let text = notification.userInfo?["text"] as? String, !text.isEmpty {
                transcriptionText = text
            }
        }
    }

    // MARK: - Dictation field

    private var dictationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Message")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                audioManager.isRecording
                                    ? OnboardingTheme.accent.opacity(0.7)
                                    : Color.primary.opacity(0.12),
                                lineWidth: audioManager.isRecording ? 1.8 : 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)

                HStack(alignment: .center, spacing: 8) {
                    if audioManager.isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                    } else if !transcriptionText.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }

                    ScrollView {
                        Text(fieldPlaceholderText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(transcriptionText.isEmpty && !audioManager.isRecording ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 4)
                            .accessibilityIdentifier("onboarding.liveDemo.resultText")
                    }
                    .frame(height: 64)
                }
                .padding(.horizontal, 12)
            }

            Text(transcriptionCaption)
                .font(.system(size: 11))
                .foregroundColor(transcriptionText.isEmpty ? .secondary : OnboardingTheme.accent)
                .accessibilityIdentifier("onboarding.liveDemo.resultCaption")
        }
    }

    private var fieldPlaceholderText: String {
        if audioManager.isRecording {
            return transcriptionText.isEmpty ? "Listening to your voice…" : transcriptionText
        }
        return transcriptionText.isEmpty ? "Your words will appear here…" : transcriptionText
    }

    // MARK: - Record button

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(
                        audioManager.isRecording
                            ? AnyGradient(Gradient(colors: [Color.red, Color.red.opacity(0.7)]))
                            : AnyGradient(Gradient(colors: [OnboardingTheme.accent, OnboardingTheme.accent2]))
                    )
                    .frame(width: 72, height: 72)
                    .shadow(
                        color: (audioManager.isRecording ? Color.red : OnboardingTheme.accent).opacity(0.4),
                        radius: 10, x: 0, y: 5
                    )

                if audioManager.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                        .frame(width: 68, height: 68)
                        .scaleEffect(1.0 + CGFloat(audioManager.audioLevel) * 0.5)
                }

                Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }

    // MARK: - Waveform

    @ViewBuilder
    private var waveform: some View {
        if audioManager.isRecording {
            LiveWaveformView()
        } else {
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(OnboardingTheme.accent.opacity(0.3))
                        .frame(width: 4, height: CGFloat.random(in: 10...30))
                }
            }
            .frame(height: 80)
        }
    }

    // MARK: - Recording

    private func toggleRecording() {
        if audioManager.isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        transcriptionText = ""
        transcriptionCaption = "Recording… speak now."

        #if DEBUG
        // UI tests must not depend on microphone permissions, speaker routing,
        // or model compilation. Exercise the same visible result state with a
        // deterministic local fixture while keeping production launches real.
        if ProcessInfo.processInfo.arguments.contains("--ui-test-force-onboarding") {
            isProcessing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard self.isProcessing else { return }
                self.isProcessing = false
                self.transcriptionText = "Hello from EchoTune onboarding test"
                self.transcriptionCaption = "Transcribed successfully using UI test fixture!"
            }
            return
        }
        #endif

        // 7.4.4: don't arm the auto-stop timer if capture never started.
        guard audioManager.startRecording().isSuccess else {
            debugLog("⚠️ Live demo could not start audio capture")
            return
        }

        // Auto stop after 15 seconds
        autoStopTimer = Just(0)
            .delay(for: .seconds(15), scheduler: RunLoop.main)
            .sink { _ in
                if self.audioManager.isRecording {
                    debugLog("⏱️ Live demo auto-stop triggered after 15s")
                    self.stopAndTranscribe()
                }
            }
    }

    private func stopAndTranscribe() {
        autoStopTimer?.cancel()
        autoStopTimer = nil

        let defaultModel = ModelManager.shared.currentModel ?? AIModel(
            id: "apple-speech",
            name: "Apple Speech",
            size: 0,
            description: "",
            language: "English",
            url: URL(string: "https://developer.apple.com/documentation/speech")!,
            type: .fast,
            category: .local,
            speedRating: 4,
            accuracyRating: 3,
            isBuiltIn: true
        )

        let engine: AudioManager.AudioEngine
        if defaultModel.id == "apple-speech" {
            engine = .appleSpeech
        } else if defaultModel.category == .cloud {
            engine = .cloud
        } else {
            engine = .whisper
        }

        guard let audioData = audioManager.stopRecording(forEngine: engine) else {
            transcriptionCaption = "No audio was captured"
            transcriptionText = "No audio was captured"
            return
        }

        isProcessing = true
        transcriptionCaption = "Converting voice to text…"

        transcriptionEngine.transcribeAudio(audioData) { result in
            isProcessing = false
            switch result {
            case .success(let text):
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    transcriptionText = "No words were detected"
                    transcriptionCaption = "Audio captured but no speech recognized."
                } else {
                    transcriptionText = text
                    transcriptionCaption = "Transcribed successfully using \(defaultModel.name)!"
                }
            case .failure(let error):
                transcriptionText = "Failed to transcribe."
                transcriptionCaption = "Error: \(error.localizedDescription)"
            }
        }
    }
}
