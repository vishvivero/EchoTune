//
//  OnboardingComponents.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import Combine

// MARK: - Live Waveform Visualization
struct LiveWaveformView: View {
    @ObservedObject private var audioManager = AudioManager.shared

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let level = CGFloat(audioManager.audioLevel)
                let amplitude = max(level * 40.0, 4.0)
                let phaseVal = CGFloat(timeline.date.timeIntervalSince1970 * 4.0)

                let width = size.width
                let height = size.height
                let midY = height / 2.0
                let grad = Gradient(colors: [OnboardingTheme.accent, OnboardingTheme.accent.opacity(0.5)])

                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY))
                for x in stride(from: CGFloat(0), through: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin(relativeX * .pi * 4 + phaseVal * 1.5)
                    let envelope = sin(relativeX * .pi)
                    let y = midY + sine * amplitude * envelope
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: width, y: height)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
        }
        .frame(height: 100)
    }
}

// MARK: - Dot Progress Indicators
struct StepIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? OnboardingTheme.accent : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentStep ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
            }
        }
    }
}

// MARK: - Card Container (matches the main dashboard's card styling)
struct OnboardingCardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
    }
}
