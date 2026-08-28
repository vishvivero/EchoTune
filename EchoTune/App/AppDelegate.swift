//
//  AppDelegate.swift
//  EchoTune
//
//  Phase 1: Application Delegate & Menu Bar Setup
//

import SwiftUI
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusBarController: StatusBarController?
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    private let onboardingState = OnboardingStateStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("🚀 EchoTune launching...")

        // Initialize status bar (always show for accessory apps)
        statusBarController = StatusBarController()
        debugLog("✓ Menu bar icon created")

        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.setupNotificationCategories()

        // Set activation policy based on onboarding state
        // Onboarding itself is now rendered inline inside the SwiftUI WindowGroup
        let hasCompletedOnboarding = onboardingState.hasCompletedOnboarding
        updateActivationPolicy(hasCompletedOnboarding: hasCompletedOnboarding)
        debugLog("📋 Onboarding completed: \(hasCompletedOnboarding)")

        // Model preloading is handled by AppCoordinator.initializeAfterOnboarding()
        // (waits for ModelManagerReady notification to avoid race conditions)

        debugLog("✓ EchoTune ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugLog("👋 EchoTune shutting down")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // No custom notification actions currently require handling
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
            onboardingWindow?.styleMask = [.titled]
            onboardingWindow?.titlebarAppearsTransparent = false
            onboardingWindow?.setContentSize(NSSize(width: 700, height: 650))
            onboardingWindow?.minSize = NSSize(width: 700, height: 650)
            onboardingWindow?.maxSize = NSSize(width: 700, height: 650)
            onboardingWindow?.center()
            onboardingWindow?.isReleasedWhenClosed = false
            onboardingWindow?.collectionBehavior = [.moveToActiveSpace]
            debugLog("🪟 Onboarding window created")
        }

        // Hide any auto-created SwiftUI windows so onboarding is the only first-launch surface.
        hidePrimaryAppWindows()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.hidePrimaryAppWindows()
        }

        // Show onboarding as the primary first-launch experience.
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        onboardingWindow?.orderFrontRegardless()
        debugLog("🪟 Onboarding window shown")
    }

    @objc func showSettings(_ sender: Any? = nil) {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(AppCoordinator.shared)
                .environmentObject(AppSettings.shared)
            let hostingController = NSHostingController(rootView: settingsView)

            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "EchoTune Settings"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow?.setContentSize(NSSize(width: 465, height: 345))
            settingsWindow?.minSize = NSSize(width: 465, height: 345)
            settingsWindow?.maxSize = NSSize(width: 900, height: 700)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false

            // Handle window close
            settingsWindow?.delegate = self
        }

        // Apply the compact default size on every show — the window is reused
        // across shows (isReleasedWhenClosed=false), so a one-time setContentSize
        // at creation doesn't survive size changes elsewhere.
        settingsWindow?.setContentSize(NSSize(width: 465, height: 345))
        settingsWindow?.minSize = NSSize(width: 465, height: 345)
        settingsWindow?.maxSize = NSSize(width: 900, height: 700)
        settingsWindow?.center()

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

    func resetOnboardingAndRestart() {
        OnboardingStateStore.shared.resetProgress()
        debugLog("🔄 Onboarding reset - restarting app...")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [Bundle.main.bundlePath]

        do {
            try task.run()
        } catch {
            debugLog("❌ Failed to restart app after onboarding reset: \(error)")
        }

        NSApp.terminate(nil)
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
