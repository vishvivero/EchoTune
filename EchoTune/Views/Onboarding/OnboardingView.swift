//
//  OnboardingView.swift
//  EchoTune
//
//  World-class 6-step onboarding:
//  Welcome -> Permissions -> Setup -> Live Demo -> Features -> Trial CTA
//
//  Step views and shared components are in sibling files under Views/Onboarding/.
//

import SwiftUI
import AVFoundation

// MARK: - Main OnboardingView

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentStep: Int
    @State private var direction: Int = 1

    private let onboardingState = OnboardingStateStore.shared
    private static let totalSteps = 6
    private let totalSteps = Self.totalSteps

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _currentStep = State(initialValue: OnboardingStateStore.shared.resumeStep(totalSteps: Self.totalSteps))
    }

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.echoPrimary.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep(onNext: goForward)
                    case 1:
                        PermissionsStep(onNext: goForward, onBack: goBack)
                    case 2:
                        SetupStep(onNext: goForward, onBack: goBack)
                    case 3:
                        LiveDemoStep(onNext: goForward, onBack: goBack)
                    case 4:
                        PowerFeaturesStep(onNext: goForward, onBack: goBack)
                    case 5:
                        TrialCTAStep(onFinish: completeOnboarding, onBack: goBack)
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))
                .id(currentStep)

                StepIndicator(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 700, height: 650)
        .onAppear {
            onboardingState.setCurrentStep(currentStep)
        }
    }

    private func goForward() {
        direction = 1
        let nextStep = min(currentStep + 1, totalSteps - 1)
        onboardingState.setCurrentStep(nextStep)
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = nextStep
        }
    }

    private func goBack() {
        direction = -1
        let previousStep = max(currentStep - 1, 0)
        onboardingState.setCurrentStep(previousStep)
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = previousStep
        }
    }

    private func completeOnboarding() {
        onboardingState.completeOnboarding()
        NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
        .frame(width: 700, height: 650)
}
