//
//  EchoTuneApp.swift
//  EchoTune
//
//  Phase 1: Main Application Entry Point
//

import SwiftUI
import Combine
import Sentry

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
    @StateObject private var onboardingState = OnboardingStateStore.shared

    init() {
        // Crash reporting is strictly opt-in via "Share Anonymous Usage
        // Analytics" in Settings > Privacy (default OFF). When enabled, no
        // personally identifying information is attached and performance
        // tracing is sampled minimally. Takes effect on next launch.
        if AppSettings.shared.shareAnalytics {
            SentrySDK.start { options in
                options.dsn = "https://86b131825ccff6bdfcd747f6b8e9a699@o4510892828327936.ingest.us.sentry.io/4510892836323328"
                options.debug = false
                options.sendDefaultPii = false
                options.tracesSampleRate = 0.05
                options.enableAutoSessionTracking = true
            }
        }

        // Initialize app coordinator to setup hotkeys and managers
        _ = AppCoordinator.shared
    }

    var body: some Scene {
        // Main window — shows onboarding until completed, then full dashboard
        WindowGroup {
            Group {
                if onboardingState.hasCompletedOnboarding {
                    MainDashboardView()
                        .environmentObject(AppCoordinator.shared)
                        .environmentObject(AppSettings.shared)
                        .frame(minWidth: 840, minHeight: 570)
                } else {
                    OnboardingView(onComplete: onboardingCompleted)
                        .frame(width: 700, height: 650)
                }
            }
            .onOpenURL(perform: handleURL)
        }
        .defaultSize(
            width: onboardingState.hasCompletedOnboarding ? 900 : 700,
            height: onboardingState.hasCompletedOnboarding ? 600 : 650
        )

        // Settings: routed through AppCoordinator → AppDelegate's controlled
        // NSWindow (compact 465x345). The SwiftUI `Settings` scene was removed
        // because it opened its own uncontrolled window (900x450) that ignored
        // our sizing — Cmd+, is handled by the command below instead.
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil)
                }
                .keyboardShortcut(",")
            }
        }
    }

    /// Called when the user finishes the in-window onboarding flow.
    private func onboardingCompleted() {
        debugLog("✓ Onboarding completed (inline SwiftUI flow)")

        // Switch to menu-bar-only (accessory) activation policy
        NSApp.setActivationPolicy(.accessory)
        debugLog("✓ Switched to .accessory activation policy")

        // Tell AppCoordinator to initialize managers that were deferred
        NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)

        // Bring the main dashboard window to the front after SwiftUI re-renders
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            if let mainWindow = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
                mainWindow.makeKeyAndOrderFront(nil)
                mainWindow.orderFrontRegardless()
                debugLog("🪟 Main dashboard brought to front after onboarding")
            }
        }
    }

    /// Handle echotune:// and https://echotune.app/refer?code=XXX deep links.
    /// Deep-link input is attacker-controllable, so the referral code is
    /// strictly validated before anything is stored.
    private func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
            guard (4...32).contains(code.count),
                  code.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                debugLog("📎 Ignoring malformed referral code in deep link")
                return
            }
            debugLog("📎 Referral code received via deep link: \(code)")
            UserDefaults.standard.set(code, forKey: "pendingReferralCode")
        }
    }
}
