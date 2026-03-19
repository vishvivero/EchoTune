//
//  OnboardingComponents.swift
//  EchoTune
//
//  Reusable UI components shared across onboarding steps:
//  StepIndicator, AppIconView, WaveformAnimation, AudioLevelBars,
//  AudioLevelWaveform, SetupCard, PrimaryButton, BackButton.
//

import SwiftUI

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Color.echoPrimary : Color.echoTextTertiary.opacity(0.5))
                    .frame(width: index == currentStep ? 24 : 8, height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.echoPrimary, Color.echoAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .shadow(color: Color.echoPrimary.opacity(0.4), radius: 20, y: 8)

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    let heights: [CGFloat] = [18, 30, 42, 30, 18]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 6, height: heights[i])
                }
            }
        }
    }
}

// MARK: - Waveform Animation

struct WaveformAnimation: View {
    var phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width

            for wave in 0..<3 {
                let amplitude: CGFloat = [20, 14, 8][wave]
                let frequency: CGFloat = [1.2, 1.8, 2.5][wave]
                let phaseShift: CGFloat = [0, 0.5, 1.0][wave]
                let opacity: Float = [0.15, 0.10, 0.06][wave]

                var path = Path()
                for x in stride(from: 0, through: width, by: 1) {
                    let relX = x / width
                    let envelope = sin(relX * .pi)
                    let y = midY + sin(relX * .pi * 2 * frequency + phase + phaseShift) * amplitude * envelope
                    if x == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(Color.echoPrimary.opacity(Double(opacity * 3))),
                    lineWidth: 2
                )
            }
        }
    }
}

// MARK: - Audio Level Bars (mic setup)

struct AudioLevelBars: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        levels[i] > 0.3
                            ? Color.echoPrimary
                            : Color.echoPrimary.opacity(0.3)
                    )
                    .frame(width: 3, height: max(2, levels[i] * 18))
            }
        }
    }
}

// MARK: - Audio Level Waveform (live demo)

struct AudioLevelWaveform: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.echoPrimary, Color.echoAccent],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: max(4, levels[i] * 60))
            }
        }
    }
}

// MARK: - Setup Card

struct SetupCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.echoPrimary.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.echoPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.echoTextPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
            }

            Spacer()

            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.echoBorder, lineWidth: 1)
        )
    }
}

// MARK: - Shared Buttons

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 220, height: 44)
                .background(
                    LinearGradient(
                        colors: disabled
                            ? [Color.echoTextTertiary, Color.echoTextTertiary]
                            : [Color.echoPrimary, Color.echoPrimary.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: disabled ? Color.clear : Color.echoPrimary.opacity(0.3), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.echoTextSecondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.top, 28)
    }
}
