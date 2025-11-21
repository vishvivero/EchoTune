//
//  WelcomeView.swift
//  EchoTune
//
//  Animated welcome screen with typing effect
//

import SwiftUI

struct WelcomeView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var currentMessageIndex = 0
    @State private var displayedText = ""
    @State private var isTyping = true
    @State private var showButton = false

    private let messages = [
        "Transform your voice into text",
        "Work faster, type less",
        "AI-powered dictation for Mac"
    ]

    private let typingSpeed: TimeInterval = 0.05
    private let deletingSpeed: TimeInterval = 0.03
    private let pauseDuration: TimeInterval = 2.0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // App Icon
            Image(systemName: "mic.circle.fill")
                .resizable()
                .frame(width: 120, height: 120)
                .foregroundStyle(.blue.gradient)
                .shadow(color: .blue.opacity(0.3), radius: 20)

            // App Name
            Text("EchoTune")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Animated typing text
            VStack(spacing: 8) {
                Text(displayedText)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(height: 60)
                    .multilineTextAlignment(.center)

                // Typing cursor
                if isTyping && !showButton {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 2, height: 24)
                        .opacity(cursorOpacity)
                }
            }
            .frame(minHeight: 100)

            Spacer()

            // Get Started button
            if showButton {
                Button(action: {
                    coordinator.nextStep()
                }) {
                    HStack(spacing: 12) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()
                .frame(height: 60)
        }
        .padding(40)
        .onAppear {
            startTypingAnimation()
        }
    }

    private var cursorOpacity: Double {
        // Blinking cursor effect
        return 1.0 // Will be animated
    }

    private func startTypingAnimation() {
        Task {
            // Wait a moment before starting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            while currentMessageIndex < messages.count {
                // Type out the message
                await typeMessage(messages[currentMessageIndex])

                // Pause
                try? await Task.sleep(nanoseconds: UInt64(pauseDuration * 1_000_000_000))

                // Delete the message (unless it's the last one)
                if currentMessageIndex < messages.count - 1 {
                    await deleteMessage()
                    currentMessageIndex += 1
                } else {
                    // Last message - show button
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showButton = true
                    }
                    break
                }
            }
        }
    }

    private func typeMessage(_ message: String) async {
        isTyping = true
        for character in message {
            await MainActor.run {
                displayedText += String(character)
            }
            try? await Task.sleep(nanoseconds: UInt64(typingSpeed * 1_000_000_000))
        }
    }

    private func deleteMessage() async {
        while !displayedText.isEmpty {
            await MainActor.run {
                displayedText.removeLast()
            }
            try? await Task.sleep(nanoseconds: UInt64(deletingSpeed * 1_000_000_000))
        }
    }
}

// Blinking cursor animation
extension WelcomeView {
    var cursorAnimation: Animation {
        .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    }
}

#Preview {
    WelcomeView()
        .environment(OnboardingCoordinator.shared)
        .frame(width: 800, height: 600)
}
