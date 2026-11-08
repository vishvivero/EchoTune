//
//  AuroraBackgroundView.swift
//  EchoTune
//
//  Onboarding 7.5.1: soft animated aurora backdrop, in the spirit of
//  superwhisper's onboarding. A single Canvas pass with radial gradients —
//  no real blur, so it stays cheap on the GPU while feeling premium.
//

import SwiftUI

struct AuroraBackgroundView: View {
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawAurora(in: &context, size: size, time: t)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawAurora(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let w = size.width
        let h = size.height

        // Three drifting light blobs. Each orbits a gentle lissajous path so
        // the composition never repeats an obvious loop.
        let blobs: [(center: CGPoint, radius: CGFloat, phase: Double, speed: Double)] = [
            (CGPoint(x: w * 0.22, y: h * 0.28), radius: w * 0.55, phase: 0.0, speed: 0.11),
            (CGPoint(x: w * 0.82, y: h * 0.62), radius: w * 0.50, phase: 2.1, speed: 0.08),
            (CGPoint(x: w * 0.50, y: h * 0.85), radius: w * 0.60, phase: 4.4, speed: 0.06)
        ]

        let colors: [Color] = [
            OnboardingTheme.accent.opacity(0.16 * intensity),
            OnboardingTheme.keyHighlight.opacity(0.10 * intensity),
            OnboardingTheme.accent2.opacity(0.14 * intensity)
        ]

        for (index, blob) in blobs.enumerated() {
            let t = time * blob.speed + blob.phase
            let dx = CGFloat(sin(t)) * w * 0.06
            let dy = CGFloat(cos(t * 1.3)) * h * 0.05
            let center = CGPoint(x: blob.center.x + dx, y: blob.center.y + dy)
            let radius = blob.radius * (1.0 + 0.06 * CGFloat(sin(t * 0.7)))

            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let gradient = Gradient(colors: [colors[index], colors[index].opacity(0)])
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius)
            )
        }
    }
}
