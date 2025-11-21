//
//  TryItOutView.swift
//  EchoTune
//
//  Interactive "try it" step where user tests the recording
//

import SwiftUI

struct TryItOutView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var transcribedText = ""
    @State private var isRecording = false
    @State private var showCompleteButton = false
    @State private var hasClickedTextArea = false

    private let placeholderText = "Click here, then press fn to start recording..."

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon with animation
            ZStack {
                // Pulsing ring when recording
                if isRecording {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(animationScale)
                        .opacity(animationOpacity)
                }

                Circle()
                    .fill(isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: isRecording ? "mic.fill" : "mic.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(isRecording ? .red : .blue)
            }

            VStack(spacing: 16) {
                Text("Try It Out!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                Text("Let's test your setup. Follow the steps below to record your first transcription.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                InstructionItem(
                    number: 1,
                    text: "Click in the text area below",
                    isCompleted: hasClickedTextArea
                )

                InstructionItem(
                    number: 2,
                    text: "Press fn (Function key) to start recording",
                    isCompleted: false
                )

                InstructionItem(
                    number: 3,
                    text: "Say something like \"Hello, this is my first transcription\"",
                    isCompleted: false
                )

                InstructionItem(
                    number: 4,
                    text: "Press fn again to stop and see the magic happen!",
                    isCompleted: !transcribedText.isEmpty
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 500)

            // Text area for testing
            ZStack(alignment: .topLeading) {
                TextEditor(text: $transcribedText)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(16)
                    .background(Color.clear)
                    .cornerRadius(10)
                    .frame(height: 120)
                    .onTapGesture {
                        hasClickedTextArea = true
                    }

                if transcribedText.isEmpty {
                    Text(placeholderText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(hasClickedTextArea ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .frame(maxWidth: 500)

            // Recording indicator
            if isRecording {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .opacity(pulseOpacity)

                    Text("Recording... Press fn to stop")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(20)
            }

            Spacer()

            // Complete Setup button (appears when text is transcribed)
            if showCompleteButton {
                Button(action: {
                    coordinator.hasTriedRecording = true
                    coordinator.trialTranscriptionText = transcribedText
                    coordinator.completeOnboarding()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))

                        Text("Complete Setup")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(40)
        .onChange(of: transcribedText) { oldValue, newValue in
            if !newValue.isEmpty && !showCompleteButton {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
                    showCompleteButton = true
                }
            }
        }
        .onAppear {
            // Simulate recording for demo purposes
            // In real app, this would connect to actual RecordingManager
            setupKeyboardMonitoring()
        }
    }

    // Animation values
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    @State private var pulseOpacity: Double = 1.0

    private func setupKeyboardMonitoring() {
        // This is a simplified version - actual implementation would use
        // NSEvent.addGlobalMonitorForEvents or similar
        // For now, we'll simulate with a button press in the preview

        // Start pulsing animation if recording
        if isRecording {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animationScale = 1.2
                animationOpacity = 0.0
            }

            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
    }

    // For testing in preview
    private func simulateRecording() {
        isRecording.toggle()

        if !isRecording && hasClickedTextArea {
            // Simulate transcription
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                transcribedText = "Hello, this is my first transcription with EchoTune!"
            }
        }
    }
}

struct InstructionItem: View {
    let number: Int
    let text: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
            }

            Text(text)
                .font(.system(size: 14, weight: isCompleted ? .semibold : .regular))
                .foregroundColor(isCompleted ? .green : .primary)
                .strikethrough(isCompleted, color: .green)

            Spacer()
        }
    }
}

#Preview {
    TryItOutView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
