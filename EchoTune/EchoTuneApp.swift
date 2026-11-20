//
//  EchoTuneApp.swift
//  EchoTune
//
//  Phase 1: Main Application Entry Point
//

import SwiftUI
import Combine

final class OnboardingStateStore: ObservableObject {
    static let shared = OnboardingStateStore()

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let currentOnboardingStep = "currentOnboardingStep"
    }

    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var currentStep: Int

    private init(userDefaults: UserDefaults = .standard) {
        let processInfo = ProcessInfo.processInfo
        let arguments = processInfo.arguments
        let environment = processInfo.environment

        let forcedHasCompletedOnboarding: Bool?
        if arguments.contains("--ui-test-force-onboarding") {
            forcedHasCompletedOnboarding = false
        } else if let rawValue = environment["ECHO_UI_TEST_FORCE_ONBOARDING"]?.lowercased() {
            forcedHasCompletedOnboarding = !(rawValue == "1" || rawValue == "true" || rawValue == "yes")
        } else {
            forcedHasCompletedOnboarding = nil
        }

        let forcedStepFromArguments: Int? = {
            guard let flagIndex = arguments.firstIndex(of: "--ui-test-onboarding-step"), arguments.indices.contains(flagIndex + 1) else {
                return nil
            }
            return Int(arguments[flagIndex + 1])
        }()

        let forcedStep = forcedStepFromArguments ?? environment["ECHO_UI_TEST_ONBOARDING_STEP"].flatMap(Int.init)

        hasCompletedOnboarding = forcedHasCompletedOnboarding ?? userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        currentStep = forcedStep.map { max($0, 0) } ?? userDefaults.integer(forKey: Keys.currentOnboardingStep)
    }

    func resumeStep(totalSteps: Int) -> Int {
        guard !hasCompletedOnboarding else { return 0 }

        let processInfo = ProcessInfo.processInfo
        let arguments = processInfo.arguments
        let environment = processInfo.environment

        let forcedStepFromArguments: Int? = {
            guard let flagIndex = arguments.firstIndex(of: "--ui-test-onboarding-step"), arguments.indices.contains(flagIndex + 1) else {
                return nil
            }
            return Int(arguments[flagIndex + 1])
        }()

        if let forcedStep = forcedStepFromArguments ?? environment["ECHO_UI_TEST_ONBOARDING_STEP"].flatMap(Int.init) {
            return min(max(forcedStep, 0), max(totalSteps - 1, 0))
        }

        // Return the saved step, clamped to a valid range.
        return min(max(currentStep, 0), max(totalSteps - 1, 0))
    }

    func setCurrentStep(_ step: Int) {
        let clampedStep = max(step, 0)
        currentStep = clampedStep
        UserDefaults.standard.set(clampedStep, forKey: Keys.currentOnboardingStep)
    }

    func resetProgress() {
        hasCompletedOnboarding = false
        currentStep = 0
        UserDefaults.standard.set(false, forKey: Keys.hasCompletedOnboarding)
        UserDefaults.standard.set(0, forKey: Keys.currentOnboardingStep)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        currentStep = 0
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: Keys.currentOnboardingStep)
    }
}

@main
struct EchoTuneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = AppCoordinator.shared
    }

    var body: some Scene {
        // Primary Dashboard & Onboarding windows are managed solely by AppDelegate
        // as single-instance NSWindows so SwiftUI WindowGroup never spawns stacked
        // duplicate windows or blocks red traffic-light Close (✕) clicks.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil)
                }
                .keyboardShortcut(",")
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    UpdateManager.shared.checkForUpdates()
                }
            }
        }
    }
}
