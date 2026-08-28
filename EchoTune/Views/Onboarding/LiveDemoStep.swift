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

                Text("Let's record a quick phrase to verify your microphone and chosen AI engine work perfectly together.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)

            // Audio Waveform Visualization
            if audioManager.isRecording {
                LiveWaveformView()
                    .padding(.horizontal, 40)
                    .frame(height: 100)
            } else {
                // Static placeholder wave
                HStack(spacing: 4) {
                    ForEach(0..<20, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(OnboardingTheme.accent.opacity(0.3))
                            .frame(width: 4, height: CGFloat.random(in: 10...30))
                    }
                }
                .frame(height: 100)
            }

            // Record Button
            VStack(spacing: 12) {
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(
                                audioManager.isRecording
                                    ? AnyGradient(Gradient(colors: [Color.red, Color.red.opacity(0.7)]))
                                    : AnyGradient(Gradient(colors: [OnboardingTheme.accent, OnboardingTheme.accent2]))
                            )
                            .frame(width: 80, height: 80)
                            .shadow(
                                color: (audioManager.isRecording ? Color.red : OnboardingTheme.accent).opacity(0.4),
                                radius: 10, x: 0, y: 5
                            )

                        if audioManager.isRecording {
                            Circle()
                                .stroke(Color.red.opacity(0.6), lineWidth: 2)
                                .frame(width: 76, height: 76)
                                .scaleEffect(1.0 + CGFloat(audioManager.audioLevel) * 0.5)
                        }

                        Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.liveDemo.recordButton")
                .disabled(isProcessing)

                Text(audioManager.isRecording ? "Recording... (\(AudioManager.formatDuration(audioManager.recordingDuration)))" : (isProcessing ? "Processing transcription..." : "Click to Speak"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            // Transcription Results Card
            OnboardingCardView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Transcription Result")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    ScrollView {
                        Text(transcriptionText.isEmpty ? (audioManager.isRecording ? "Listening to your voice..." : "Your spoken words will appear here.") : transcriptionText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(transcriptionText.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(height: 60)

                    Divider()

                    Text(transcriptionCaption)
                        .font(.system(size: 11))
                        .foregroundColor(transcriptionText.isEmpty ? .secondary : OnboardingTheme.accent)
                        .accessibilityIdentifier("onboarding.liveDemo.resultCaption")
                }
            }
            .padding(.horizontal, 20)

            // Hidden element for XCTest to read transcribed text
            Text(transcriptionText)
                .hidden()
                .accessibilityIdentifier("onboarding.liveDemo.resultText")

            Spacer()

            // Continue Button (enabled after successful demo transcription)
            if !transcriptionText.isEmpty && !isProcessing {
                Button(action: onNext) {
                    Text("Continue")
                        .frame(width: 200)
                }
                .buttonStyle(GradientProminentButtonStyle())
                .controlSize(.large)
                .padding(.bottom, 20)
            }
        }
        .onDisappear {
            autoStopTimer?.cancel()
        }
    }

    private func toggleRecording() {
        if audioManager.isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        transcriptionText = ""
        transcriptionCaption = "Recording... speak now."
        audioManager.startRecording()

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
        transcriptionCaption = "Converting voice to text..."

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
