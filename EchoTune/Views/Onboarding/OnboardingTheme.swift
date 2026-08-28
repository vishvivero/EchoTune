//
//  OnboardingTheme.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct OnboardingTheme {
    static let accent = Color.blue
    static let accent2 = Color.purple
    static let success = Color.green

    /// Primary brand gradient — matches the dashboard's gradient accents.
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Soft tint used behind icon chips (mirrors ModernSidebarItem's icon chips).
    static var chipFill: Color {
        Color.blue.opacity(0.12)
    }

    /// Card gradient fill — subtle tint blend like HomeContentView's time-saved card.
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue.opacity(0.04), Color.purple.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Success gradient (green → blue) — matches the dashboard's achievement card.
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [Color.green, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Step Header Icon Chip

    /// Rounded-rect icon chip shown above each step title — echoes the
    /// dashboard sidebar's icon chips so onboarding feels like the same app.
    struct HeaderIconChip: View {
        let systemName: String
        var tint: Color = .blue

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: tint.opacity(0.35), radius: 8, x: 0, y: 4)

                Image(systemName: systemName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}
