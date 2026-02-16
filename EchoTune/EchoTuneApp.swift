//
//  EchoTuneApp.swift
//  EchoTune
//
//  Phase 1: Main Application Entry Point
//

import SwiftUI
import Sentry

@main
struct EchoTuneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
            MainDashboardView()
                .environmentObject(AppCoordinator.shared)
                .environmentObject(AppSettings.shared)
        }

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