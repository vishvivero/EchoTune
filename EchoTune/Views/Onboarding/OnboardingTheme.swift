//
//  OnboardingTheme.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct OnboardingTheme {
    // Brand colors pulled from the app logo (cyan waveform icon)
    // and the website palette (#7ED0EB). No purple — brand is cyan.
    static let accent = Color(red: 0.44, green: 0.81, blue: 0.92)      // #70CEDF logo cyan
    static let accent2 = Color(red: 0.18, green: 0.58, blue: 0.72)     // deep cyan for gradient depth
    static let success = Color.green

    /// Primary brand gradient — logo cyan → deep cyan.
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Soft tint used behind icon chips.
    static var chipFill: Color {
        accent.opacity(0.12)
    }

    /// Card gradient fill — very subtle cyan wash.
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.05), accent2.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Success gradient (green → cyan) — matches the dashboard's achievement card.
    static var successGradient: LinearGradient {
        LinearGradient(
            colors: [Color.green, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Step Header Icon Chip

    /// Rounded-rect icon chip shown above each step title — echoes the
    /// dashboard sidebar's icon chips so onboarding feels like the same app.
    struct HeaderIconChip: View {
        let systemName: String
        var tint: Color = OnboardingTheme.accent

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: tint.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: systemName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}
