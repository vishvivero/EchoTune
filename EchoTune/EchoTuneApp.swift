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
        hasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        currentStep = userDefaults.integer(forKey: Keys.currentOnboardingStep)
    }

    func resumeStep(totalSteps: Int) -> Int {
        guard !hasCompletedOnboarding else { return 0 }
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
        // Initialize Sentry crash & error reporting
        SentrySDK.start { options in
            options.dsn = "https://86b131825ccff6bdfcd747f6b8e9a699@o4510892828327936.ingest.us.sentry.io/4510892836323328"
            options.debug = false
            options.sendDefaultPii = true
            options.tracesSampleRate = 1.0
            options.enableAutoSessionTracking = true
        }

        // Initialize app coordinator to setup hotkeys and managers
        _ = AppCoordinator.shared
    }

    var body: some Scene {
        // Main window with full dashboard
        WindowGroup {
            Group {
                if onboardingState.hasCompletedOnboarding {
                    MainDashboardView()
                        .environmentObject(AppCoordinator.shared)
                        .environmentObject(AppSettings.shared)
                } else {
                    EmptyView()
                }
            }
            .onOpenURL(perform: handleURL)
            .frame(minWidth: 900, minHeight: 700)
        }
        .defaultSize(width: 1100, height: 800)

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(AppCoordinator.shared)
                .environmentObject(AppSettings.shared)
        }
    }

    /// Handle echotune:// and https://echotune.app/refer?code=XXX deep links
    private func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        // Check for referral code in query params
        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           !code.isEmpty {
            debugLog("📎 Referral code received via deep link: \(code)")
            UserDefaults.standard.set(code, forKey: "pendingReferralCode")
        }
    }
}
