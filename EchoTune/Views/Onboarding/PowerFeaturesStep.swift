//
//  PowerFeaturesStep.swift
//  EchoTune
//
//  Onboarding Step 5: Power Features (Quick Showcase)
//

import SwiftUI

struct PowerFeaturesStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var appeared = false
    @State private var cardAppeared: [Bool] = [false, false, false, false]

    private let features: [(icon: String, title: String, subtitle: String, gradient: [Color])] = [
        ("brain.head.profile", "Context Aware", "Reads your screen to enhance transcription accuracy with context", [Color(red: 0.56, green: 0.36, blue: 0.90), Color(red: 0.72, green: 0.50, blue: 1.0)]),
        ("bolt.fill", "Power Modes", "Auto-switches settings per app \u{2014} different rules for Slack, Docs, Code", [Color(red: 0.95, green: 0.55, blue: 0.20), Color(red: 1.0, green: 0.72, blue: 0.40)]),
        ("target", "Trigger Words", "Say magic keywords to activate AI prompts \u{2014} \"fix grammar\" or \"translate\"", [Color(red: 0.20, green: 0.70, blue: 0.45), Color(red: 0.40, green: 0.85, blue: 0.60)]),
        ("lock.shield.fill", "Privacy First", "Fully offline mode available \u{2014} your voice never leaves your Mac", [Color(red: 0.22, green: 0.55, blue: 0.85), Color(red: 0.40, green: 0.70, blue: 0.95)]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)

            Spacer().frame(height: 8)

            Text("You're just getting started")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 6)

            Text("EchoTune is packed with power features.")
                .font(.system(size: 14))
                .foregroundColor(.echoTextSecondary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 28)

            // Feature cards in 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(0..<features.count, id: \.self) { index in
                    let feature = features[index]
                    FeatureShowcaseCard(
                        icon: feature.icon,
                        title: feature.title,
                        subtitle: feature.subtitle,
                        gradient: feature.gradient
                    )
                    .opacity(cardAppeared[index] ? 1 : 0)
                    .offset(y: cardAppeared[index] ? 0 : 20)
                    .scaleEffect(cardAppeared[index] ? 1.0 : 0.95)
                }
            }
            .padding(.horizontal, 48)

            Spacer()

            PrimaryButton(title: "Continue", action: onNext)

            Spacer().frame(height: 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }

            // Staggered card animations
            for i in 0..<4 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(i) * 0.12 + 0.15)) {
                    cardAppeared[i] = true
                }
            }
        }
    }
}

// MARK: - Feature Showcase Card

struct FeatureShowcaseCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Gradient icon circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.echoTextPrimary)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.echoTextSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isHovered ? gradient.first!.opacity(0.4) : Color.echoBorder,
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
