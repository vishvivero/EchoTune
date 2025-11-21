//
//  OnboardingCoordinator.swift
//  EchoTune
//
//  Manages the onboarding flow state and navigation
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case microphonePermission
    case microphoneSelection
    case accessibilityPermission
    case shortcutSetup
    case modelDownload
    case tryItOut
    case complete

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to EchoTune"
        case .microphonePermission:
            return "Microphone Access"
        case .microphoneSelection:
            return "Select Your Microphone"
        case .accessibilityPermission:
            return "Accessibility Access"
        case .shortcutSetup:
            return "Set Your Shortcut"
        case .modelDownload:
            return "Download AI Model"
        case .tryItOut:
            return "Try It Out!"
        case .complete:
            return "All Set!"
        }
    }

    var stepNumber: Int {
        // Don't count welcome and complete as numbered steps
        switch self {
        case .welcome, .complete:
            return 0
        default:
            return rawValue
        }
    }

    var totalSteps: Int {
        return 6 // Total numbered steps (excluding welcome and complete)
    }
}

@Observable
class OnboardingCoordinator {
    static let shared = OnboardingCoordinator()

    var currentStep: OnboardingStep = .welcome
    var isOnboardingComplete = false

    // State for each step
    var hasMicrophonePermission = false
    var hasAccessibilityPermission = false
    var selectedMicrophone: String?
    var selectedShortcut: KeyboardShortcut = .default
    var isModelDownloading = false
    var modelDownloadProgress: Double = 0.0
    var hasTriedRecording = false
    var trialTranscriptionText: String = ""

    private init() {
        // Check if onboarding was already completed
        isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboardingCompleted")
    }

    func nextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }

        withAnimation {
            currentStep = next
        }
    }

    func previousStep() {
        guard currentStep.rawValue > 0,
              let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }

        withAnimation {
            currentStep = previous
        }
    }

    func skipToStep(_ step: OnboardingStep) {
        withAnimation {
            currentStep = step
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        withAnimation {
            isOnboardingComplete = true
        }

        // Notify app to show main interface
        NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
    }

    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "onboardingCompleted")
        currentStep = .welcome
        isOnboardingComplete = false
        hasMicrophonePermission = false
        hasAccessibilityPermission = false
        selectedMicrophone = nil
        selectedShortcut = .default
        isModelDownloading = false
        modelDownloadProgress = 0.0
        hasTriedRecording = false
        trialTranscriptionText = ""
    }
}

struct KeyboardShortcut: Equatable {
    var key: String
    var modifiers: [String]

    static let `default` = KeyboardShortcut(key: "Fn", modifiers: [])

    var displayString: String {
        if modifiers.isEmpty {
            return key
        }
        return modifiers.joined() + key
    }
}
