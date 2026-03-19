//
//  OnboardingTheme.swift
//  EchoTune
//
//  Brand colors (adaptive light/dark) used across all onboarding views.
//

import SwiftUI

// MARK: - Brand Colors (adaptive light/dark)

extension Color {
    static let echoPrimary = Color(red: 0.18, green: 0.72, blue: 0.83)
    static let echoAccent = Color(red: 0.49, green: 0.82, blue: 0.93)

    static let echoBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)
            : NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
    })

    static let echoSurface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })

    static let echoSurfaceHover = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1)
            : NSColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1)
    })

    static let echoTextPrimary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white
            : NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    })

    static let echoTextSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.55)
            : NSColor(red: 0.40, green: 0.42, blue: 0.46, alpha: 1)
    })

    static let echoTextTertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.35)
            : NSColor(red: 0.60, green: 0.62, blue: 0.66, alpha: 1)
    })

    static let echoBorder = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.08)
            : NSColor(red: 0.88, green: 0.89, blue: 0.90, alpha: 1)
    })
}
