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
    private let onboardingState = OnboardingStateStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("🚀 EchoTune launching...")

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
        let hasCompletedOnboarding = onboardingState.hasCompletedOnboarding
        updateActivationPolicy(hasCompletedOnboarding: hasCompletedOnboarding)
        debugLog("📋 Onboarding completed: \(hasCompletedOnboarding)")

        if !hasCompletedOnboarding {
            debugLog("🎓 Showing onboarding...")
            hidePrimaryAppWindows()
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
                self.updateActivationPolicy(hasCompletedOnboarding: true)
                self.onboardingWindow?.close()
                self.onboardingWindow = nil

                self.showPrimaryAppWindows()
                self.showWelcomeNotification()
            }

            let hostingController = NSHostingController(rootView: onboardingView)

            onboardingWindow = NSWindow(contentViewController: hostingController)
            onboardingWindow?.title = "Welcome to EchoTune"
            onboardingWindow?.styleMask = [.titled, .closable]
            onboardingWindow?.titlebarAppearsTransparent = false
            onboardingWindow?.setContentSize(NSSize(width: 700, height: 600))
            onboardingWindow?.minSize = NSSize(width: 700, height: 600)
            onboardingWindow?.maxSize = NSSize(width: 700, height: 600)
            onboardingWindow?.center()
            onboardingWindow?.isReleasedWhenClosed = false
            onboardingWindow?.collectionBehavior = [.moveToActiveSpace]
            debugLog("🪟 Onboarding window created")
        }

        // Show onboarding as the primary first-launch experience.
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.orderFrontRegardless()
        debugLog("🪟 Onboarding window shown")
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
        // Hand off cleanly to the main dashboard instead of interrupting with another modal.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)

            if let mainWindow = NSApp.windows.first(where: { window in
                window != self.settingsWindow &&
                window.isVisible &&
                window.canBecomeKey
            }) {
                mainWindow.makeKeyAndOrderFront(nil)
                mainWindow.orderFrontRegardless()
                debugLog("🪟 Main dashboard brought to front after onboarding")
            } else {
                debugLog("ℹ️ Main dashboard window not yet visible after onboarding handoff")
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

    private func updateActivationPolicy(hasCompletedOnboarding: Bool) {
        let policy: NSApplication.ActivationPolicy = hasCompletedOnboarding ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
        debugLog("✓ Using \(hasCompletedOnboarding ? ".accessory" : ".regular") activation policy")
    }

    private func hidePrimaryAppWindows() {
        DispatchQueue.main.async {
            for window in NSApp.windows where window !== self.onboardingWindow && window !== self.settingsWindow {
                window.orderOut(nil)
                debugLog("🙈 Hid primary app window during onboarding: \(window.title)")
            }
        }
    }

    private func showPrimaryAppWindows() {
        DispatchQueue.main.async {
            for window in NSApp.windows where window !== self.onboardingWindow && window !== self.settingsWindow {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                debugLog("🪟 Revealed primary app window after onboarding: \(window.title)")
                break
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
