//
//  WelcomeStep.swift
//  EchoTune
//
//  Onboarding Step 1: Welcome (Emotional Hook)
//

import SwiftUI

struct WelcomeStep: View {
    let onNext: () -> Void

    @State private var appeared = false
    @State private var wavePhase: CGFloat = 0.0
    @State private var textRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated waveform -> text visual metaphor
            ZStack {
                WaveformAnimation(phase: wavePhase)
                    .frame(width: 360, height: 80)
                    .opacity(appeared ? 0.6 : 0)
                    .blur(radius: textRevealed ? 8 : 0)
                    .scaleEffect(textRevealed ? 0.8 : 1.0)

                AppIconView()
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1.0 : 0)
            }

            Spacer().frame(height: 36)

            // Bold emotional headline
            Text("Stop typing.\nStart talking.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 14)

            Spacer().frame(height: 14)

            // Pain point subtext
            Text("Your voice is 3\u{00D7} faster than your keyboard.\nEchoTune turns speech into text, instantly.")
                .font(.system(size: 16, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundColor(.echoTextSecondary)
                .lineSpacing(3)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 10)

            Spacer()

            // CTA
            PrimaryButton(title: "Get Started", action: onNext)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 16)

            Spacer().frame(height: 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                appeared = true
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 1.2).delay(1.5)) {
                textRevealed = true
            }
        }
    }
}
