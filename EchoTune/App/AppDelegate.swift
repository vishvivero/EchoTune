//
//  AppDelegate.swift
//  EchoTune
//
//  Phase 1: Application Delegate & Menu Bar Setup
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("🚀 EchoTune launching...")

        // CRITICAL FIX: Use .accessory policy to prevent focus stealing
        // This allows EchoTune to run without ever stealing focus from other apps
        // User can still access settings via menu bar
        NSApp.setActivationPolicy(.accessory)
        debugLog("✓ Using .accessory policy - will not steal focus")

        // Initialize status bar (always show for accessory apps)
        statusBarController = StatusBarController()
        debugLog("✓ Menu bar icon created")

        // Observe menu bar visibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarVisibilityChanged(_:)),
            name: NSNotification.Name("MenuBarVisibilityChanged"),
            object: nil
        )

        // Check if first launch or onboarding not completed
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        debugLog("📋 Onboarding completed: \(hasCompletedOnboarding)")

        if !hasCompletedOnboarding {
            debugLog("🎓 Showing onboarding...")
            showOnboarding()
        }

        // Model preloading is handled by AppCoordinator.initializeAfterOnboarding()
        // (waits for ModelManagerReady notification to avoid race conditions)

        debugLog("✓ EchoTune ready")
    }

    @objc func handleMenuBarVisibilityChanged(_ notification: Notification) {
        guard let shouldShow = notification.object as? Bool else { return }

        if shouldShow {
            // Show menu bar icon
            if statusBarController == nil {
                statusBarController = StatusBarController()
                debugLog("✓ Menu bar icon shown")
            }
        } else {
            // Hide menu bar icon
            statusBarController = nil
            debugLog("✓ Menu bar icon hidden")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugLog("👋 EchoTune shutting down")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows close (menu bar app)
        return false
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let onboardingView = OnboardingView {
                debugLog("✓ Onboarding completed")
                // Onboarding completed
                self.onboardingWindow?.close()
                self.onboardingWindow = nil

                // Show welcome notification
                self.showWelcomeNotification()
            }

            let hostingController = NSHostingController(rootView: onboardingView)

            onboardingWindow = NSWindow(contentViewController: hostingController)
            onboardingWindow?.title = "Welcome to EchoTune"
            onboardingWindow?.styleMask = [.titled, .closable, .resizable]
            onboardingWindow?.titlebarAppearsTransparent = false
            onboardingWindow?.setContentSize(NSSize(width: 700, height: 600))
            onboardingWindow?.minSize = NSSize(width: 700, height: 600)
            onboardingWindow?.maxSize = NSSize(width: 700, height: 600)
            onboardingWindow?.center()
            onboardingWindow?.isReleasedWhenClosed = false
            debugLog("🪟 Onboarding window created")
        }

        // Show window without stealing focus
        onboardingWindow?.makeKeyAndOrderFront(nil)
        // REMOVED: NSApp.activate(ignoringOtherApps: true) - this steals focus!
        debugLog("🪟 Onboarding window shown (without stealing focus)")
    }

    func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(AppCoordinator.shared)
                .environmentObject(AppSettings.shared)
            let hostingController = NSHostingController(rootView: settingsView)

            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "EchoTune Settings"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow?.setContentSize(NSSize(width: 700, height: 500))
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false

            // Handle window close
            settingsWindow?.delegate = self
        }

        // Show settings window without stealing focus
        settingsWindow?.makeKeyAndOrderFront(nil)
        // REMOVED: NSApp.activate(ignoringOtherApps: true) - this steals focus!
        debugLog("⚙️ Settings window shown (without stealing focus)")
    }

    func showWelcomeNotification() {
        // Show welcome alert with instructions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "🎉 Welcome to EchoTune!"
            alert.informativeText = """
            Setup complete! EchoTune is now running in your menu bar.

            Look for the microphone icon (🎤) at the top-right of your screen.

            Quick Start:
            • Press Control (⌃) anywhere to start dictating
            • Click the menu bar icon for settings and options
            • Find EchoTune in: System Settings → Privacy & Security

            Ready to try it? Press Control in any app!
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Got it!")
            alert.addButton(withTitle: "Open Settings")

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                self.showSettings()
            }
        }
    }

    // MARK: - Model Preloading

    /// Preload the default Whisper model in background for instant first transcription
    private func preloadDefaultModel() {
        // Only preload if using Whisper (not Apple Speech)
        guard let currentModel = ModelManager.shared.currentModel,
              !currentModel.isBuiltIn,
              currentModel.isInstalled else {
            debugLog("ℹ️ Skipping model preload (using Apple Speech or no model installed)")
            return
        }

        debugLog("🚀 Preloading Whisper model in background: \(currentModel.name)")
        debugLog("   This eliminates 2-3s loading delay on first transcription")

        // Preload model asynchronously in background
        Task(priority: .utility) {
            WhisperEngine.shared.loadModel(currentModel) { result in
                switch result {
                case .success:
                    debugLog("✅ Model preloaded successfully: \(currentModel.name)")
                    debugLog("🎯 First transcription will be instant!")
                case .failure(let error):
                    debugLog("⚠️ Model preload failed: \(error)")
                    debugLog("   Model will load on first transcription instead")
                }
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            // Settings window is closing
        }
    }
}
