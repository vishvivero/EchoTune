//
//  OnboardingView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @ObservedObject private var store = OnboardingStateStore.shared

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header & Progress indicators
                HStack {
                    if store.currentStep > 0 {
                        Button(action: goBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 50)
                    }

                    Spacer()

                    StepIndicatorView(currentStep: store.currentStep, totalSteps: 5)

                    Spacer()

                    Spacer()
                        .frame(width: 50)
                }
                .padding(.horizontal, 30)
                .padding(.top, 24)

                // Current Step Content Container
                ZStack {
                    switch store.currentStep {
                    case 0:
                        WelcomeStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 1:
                        PermissionsStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 2:
                        SetupStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 3:
                        LiveDemoStep(onNext: goForward)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case 4:
                        TrialCTAStep(onComplete: completeOnboarding)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    default:
                        WelcomeStep(onNext: goForward)
                            .transition(.identity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 650)
    }

    private func goForward() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            store.setCurrentStep(store.currentStep + 1)
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            store.setCurrentStep(max(store.currentStep - 1, 0))
        }
    }

    private func completeOnboarding() {
        store.completeOnboarding()
        onComplete()
    }
}
