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

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
