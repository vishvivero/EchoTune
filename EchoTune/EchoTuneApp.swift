//
//  EchoTuneApp.swift
//  EchoTune
//
//  Phase 1: Main Application Entry Point
//

import SwiftUI

@main
struct EchoTuneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
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
}