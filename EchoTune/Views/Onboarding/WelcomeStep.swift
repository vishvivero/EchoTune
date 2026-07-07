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
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)

            VStack(spacing: 12) {
                Text("Welcome to EchoTune")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("AI Voice Dictation")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(OnboardingTheme.accent)
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
                .frame(height: 20)
        }
        .padding(40)
    }
}
