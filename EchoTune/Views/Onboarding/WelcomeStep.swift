//
//  WelcomeStep.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Visual branding element — the actual EchoTune logo
            Group {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(OnboardingTheme.brandGradient)
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: OnboardingTheme.accent.opacity(0.35), radius: 16, x: 0, y: 8)
            .overlay(
                // Soft brand-glow ring behind the icon — echoes the dashboard's gradient circles
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [OnboardingTheme.accent.opacity(0.4), OnboardingTheme.accent2.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )

            VStack(spacing: 12) {
                Text("Welcome to EchoTune")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Gradient subtitle — matches HomeContentView's gradient headline treatments
                Text("AI Voice Dictation")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(OnboardingTheme.brandGradient)
            }

            Text("Type anywhere on your Mac with offline Whisper, ultra-fast cloud services, and advanced AI automation rules. Everything runs securely and with maximum performance.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4.5)
                .frame(maxWidth: 500)
                .padding(.horizontal)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
                    .frame(width: 220)
            }
            .buttonStyle(GradientProminentButtonStyle())
            .controlSize(.large)

            Spacer()
                .frame(height: 20)
        }
        .padding(40)
    }
}

// MARK: - Gradient CTA Button (matches dashboard's gradient accents)
struct GradientProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OnboardingTheme.brandGradient)
                    .shadow(color: OnboardingTheme.accent.opacity(0.35), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
