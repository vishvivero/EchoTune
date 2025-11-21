//
//  OnboardingContainerView.swift
//  EchoTune
//
//  Main container for the onboarding flow
//

import SwiftUI

struct OnboardingContainerView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            // Background
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            // Current step view
            Group {
                switch coordinator.currentStep {
                case .welcome:
                    WelcomeView()
                case .microphonePermission:
                    MicrophonePermissionView()
                case .microphoneSelection:
                    MicrophoneSelectionView()
                case .accessibilityPermission:
                    AccessibilityPermissionView()
                case .shortcutSetup:
                    ShortcutSetupView()
                case .modelDownload:
                    ModelDownloadView()
                case .tryItOut:
                    TryItOutView()
                case .complete:
                    OnboardingCompleteView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            // Progress indicator (shown for non-welcome/complete steps)
            if coordinator.currentStep != .welcome && coordinator.currentStep != .complete {
                VStack {
                    HStack(spacing: 8) {
                        ForEach(1...6, id: \.self) { step in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(step <= coordinator.currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 40, height: 4)
                        }
                    }
                    .padding(.top, 20)

                    Spacer()
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

#Preview {
    OnboardingContainerView()
        .environment(OnboardingCoordinator.shared)
}
