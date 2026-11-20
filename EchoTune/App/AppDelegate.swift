//
//  AppDelegate.swift
//  EchoTune
//
//  Application Delegate, Foreground Window Activation & Menu Bar Lifecycle
//

import AppKit
import SwiftUI
import UserNotifications

/// `kAELaunchedAsLogInItem` lives in Carbon; keep the raw four-char code local so this
/// file does not need a Carbon import just for one comparison.
private let launchedAsLogInItemCode: OSType = 0x6C67_6E20 // 'lgn '

/// Standard window subclass that guarantees foreground app activation whenever
/// clicked, ensuring Red (✕), Yellow (−), and Green (+) traffic-light buttons
/// are always colored and responsive on the very first click.
final class ActivatingStandardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && !NSApp.isActive {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate()
        }
        super.sendEvent(event)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    var statusBarController: StatusBarController?
    var settingsWindow: NSWindow?
    var dashboardWindow: NSWindow?
    var onboardingWindow: NSWindow?
    var echoProfileWindowController: EchoProfileWindowController?
    var commitmentsWindowController: CommitmentsWindowController?

    private let onboardingState = OnboardingStateStore.shared
    private let dashboardSize = NSSize(width: 960, height: 720)
    private let dashboardMinimumSize = NSSize(width: 900, height: 600)

    /// True when macOS started us at login rather than the user opening the app.
    /// Captured in `applicationWillFinishLaunching`, which is when AppKit still exposes
    /// the triggering Apple event.
    private var launchedAsLoginItem = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == AEEventID(kAEOpenApplication),
           let prop = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))
        {
            launchedAsLoginItem = prop.enumCodeValue == launchedAsLogInItemCode
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("🚀 EchoTune launching...")

        let args = ProcessInfo.processInfo.arguments
        let relaunchWaitPID: pid_t? = {
            guard let idx = args.firstIndex(of: "--relaunch-wait-pid"),
                  args.indices.contains(idx + 1),
                  let parsed = Int32(args[idx + 1]) else { return nil }
            return parsed
        }()
        if let dyingPID = relaunchWaitPID {
            for _ in 0..<40 {
                if kill(dyingPID, 0) != 0 { break }
                usleep(50_000)
            }
        }

        let selfPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "com.echotune.EchoTune")
            .filter {
                $0.processIdentifier != selfPID
                    && $0.processIdentifier != relaunchWaitPID
                    && !$0.isTerminated
            }
        let env = ProcessInfo.processInfo.environment
        let isTestHost = env["XCTestConfigurationFilePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || args.contains("--ui-test-force-onboarding")
            || env["ECHO_UI_TEST_FORCE_ONBOARDING"] != nil

        if let other = others.first, !isTestHost {
            debugLog("⚠️ EchoTune already running (pid \(other.processIdentifier)) — activating it and exiting")
            other.activate()
            NSApp.terminate(nil)
            return
        }

        _ = UpdateManager.shared

        statusBarController = StatusBarController()
        debugLog("✓ Menu bar icon created")

        _ = EchoMemoryManager.shared

        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.setupNotificationCategories()

        if !isTestHost {
            if onboardingState.hasCompletedOnboarding {
                // Stay a menu bar app so a login launch stays quiet, but when the user
                // deliberately opens EchoTune, show the Dashboard instead of booting to
                // an invisible background process that looks broken.
                NSApp.setActivationPolicy(.accessory)
                if !launchedAsLoginItem {
                    DispatchQueue.main.async { [weak self] in
                        self?.showDashboard(item: .home)
                    }
                }
            } else {
                showOnboarding()
            }
        } else if args.contains("--ui-test-force-onboarding") {
            DispatchQueue.main.async { [weak self] in
                self?.showOnboarding()
            }
        }

        debugLog("✓ EchoTune ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugLog("👋 EchoTune shutting down")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if onboardingState.hasCompletedOnboarding {
            showDashboard(item: .home)
        } else {
            showOnboarding()
        }
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { continue }
            if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
                if (4...32).contains(code.count), code.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                    UserDefaults.standard.set(code, forKey: "pendingReferralCode")
                }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {}

    // MARK: - Window Activation & Policy Lifecycle

    private func activateAndPresent(_ window: NSWindow) {
        // A window that was dragged (or restored) off-screen has no reachable title bar,
        // so its traffic lights look absent and every click lands on whatever is behind it.
        // Put it back on screen before showing it.
        keepWindowReachable(window)
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        if !NSApp.isActive {
            NSApp.activate()
        }
    }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let managed: [NSWindow?] = [
                self.dashboardWindow,
                self.settingsWindow,
                self.onboardingWindow,
                self.echoProfileWindowController?.window,
                self.commitmentsWindowController?.window
            ]
            let anyStillVisibleOrMiniaturized = managed.compactMap { $0 }.contains { win in
                win !== closing && (win.isVisible || win.isMiniaturized)
            }
            if !anyStillVisibleOrMiniaturized && self.onboardingState.hasCompletedOnboarding {
                if NSApp.activationPolicy() != .accessory {
                    NSApp.setActivationPolicy(.accessory)
                    // NOTE: deliberately no status-item re-vend here. Replacing the
                    // NSStatusItem tears down Control Center's tracked status-item scene
                    // (appStatusItems host removal) on macOS 26, and the re-registered item
                    // could keep drawing but stop forwarding clicks. A single long-lived
                    // status item with `statusItem.menu` set is the configuration macOS
                    // handles natively — that is how the other working menu bar apps behave.
                }
            }
        }
    }

    // MARK: - On-Screen Frame Safety

    /// Guarantees a managed window is actually reachable. Returns true when the frame was repaired.
    @discardableResult
    func keepWindowReachable(_ window: NSWindow, recenterIfUnreachable: Bool = true) -> Bool {
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return false }
        let visible = screen.visibleFrame
        var frame = window.frame

        // Minimum sliver of the window that must be inside visibleFrame: the full title
        // bar height plus a wide grab area, so traffic lights and title bar drag stay usable.
        let titleBarHeight = max(28, frame.height - window.contentLayoutRect.height)
        let requiredWidth = min(frame.width, 260)
        let requiredHeight = titleBarHeight + 40

        let hasUsableTitleBar = frame.maxY <= visible.maxY + 0.5
            && frame.maxY >= visible.minY + requiredHeight
            && frame.maxX >= visible.minX + requiredWidth
            && frame.minX <= visible.maxX - requiredWidth

        if hasUsableTitleBar {
            return false
        }

        if recenterIfUnreachable {
            let size = NSSize(
                width: min(frame.width, visible.width),
                height: min(frame.height, visible.height)
            )
            frame.size = size
            frame.origin = NSPoint(
                x: visible.minX + (visible.width - size.width) / 2,
                y: visible.minY + (visible.height - size.height) / 2
            )
            debugLog("🪟 Recentred off-screen window '\(window.title)' into visibleFrame \(visible)")
        } else {
            frame.origin.x = min(max(frame.origin.x, visible.minX), max(visible.minX, visible.maxX - requiredWidth))
            frame.origin.y = min(max(frame.origin.y, visible.minY + requiredHeight - frame.height), visible.maxY - titleBarHeight)
            debugLog("🪟 Clamped off-screen window '\(window.title)' back on screen")
        }

        window.setFrame(frame, display: true)
        return true
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.isVisible else { return }
        // Only rescue a window that has drifted so far it can no longer be grabbed.
        _ = keepWindowReachable(window, recenterIfUnreachable: false)
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.isVisible else { return }
        keepWindowReachable(window)
    }

    // MARK: - Primary Windows

    func showOnboarding() {
        if onboardingWindow == nil {
            let onboardingView = OnboardingView { [weak self] in
                guard let self else { return }
                debugLog("✓ Onboarding completed")
                NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                self.showDashboard(item: .home)
            }

            let hostingController = NSHostingController(rootView: onboardingView)
            let win = ActivatingStandardWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 650),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.contentViewController = hostingController
            win.title = "Welcome to EchoTune"
            win.titlebarAppearsTransparent = false
            win.setContentSize(NSSize(width: 700, height: 650))
            win.minSize = NSSize(width: 700, height: 650)
            win.maxSize = NSSize(width: 700, height: 650)
            win.center()
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.collectionBehavior = [.moveToActiveSpace]
            onboardingWindow = win
        }

        if let win = onboardingWindow {
            activateAndPresent(win)
        }
    }

    func showDashboard(item: NavigationItem = .home) {
        if dashboardWindow == nil {
            let root = MainDashboardView()
                .environmentObject(AppCoordinator.shared)
                .environmentObject(AppSettings.shared)
            let hosting = NSHostingController(rootView: root)
            let win = ActivatingStandardWindow(
                contentRect: NSRect(origin: .zero, size: dashboardSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.contentViewController = hosting
            win.title = "EchoTune"
            win.minSize = dashboardMinimumSize
            win.setContentSize(dashboardSize)
            win.center()
            win.isReleasedWhenClosed = false
            win.delegate = self
            dashboardWindow = win
        }

        if let win = dashboardWindow {
            if win.isMiniaturized {
                win.deminiaturize(nil)
            }
            activateAndPresent(win)
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateDashboardToItem"),
                object: nil,
                userInfo: ["item": item.rawValue]
            )
        }
    }

    @objc func showSettings(_ sender: Any? = nil) {
        showSettings(tab: nil)
    }

    func showSettings(tab: SettingsTab?) {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(AppCoordinator.shared)
                .environmentObject(AppSettings.shared)
            let hostingController = NSHostingController(rootView: settingsView)

            let win = ActivatingStandardWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.contentViewController = hostingController
            win.title = "EchoTune Settings"
            win.setContentSize(NSSize(width: 720, height: 480))
            win.minSize = NSSize(width: 680, height: 420)
            win.maxSize = NSSize(width: 1100, height: 800)
            win.center()
            win.isReleasedWhenClosed = false
            win.delegate = self
            settingsWindow = win
        }

        if let tab {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateSettingsToTab"),
                object: nil,
                userInfo: ["tab": tab.rawValue]
            )
        }

        if let win = settingsWindow {
            if win.isMiniaturized {
                win.deminiaturize(nil)
            }
            if !win.isVisible {
                win.setContentSize(NSSize(width: 720, height: 480))
                win.center()
            }
            activateAndPresent(win)
        }
    }

    @objc func showEchoProfile() {
        if echoProfileWindowController == nil {
            echoProfileWindowController = EchoProfileWindowController()
            echoProfileWindowController?.window?.delegate = self
        }
        if let win = echoProfileWindowController?.window {
            win.center()
            activateAndPresent(win)
        }
    }

    @objc func showCommitments() {
        if commitmentsWindowController == nil {
            commitmentsWindowController = CommitmentsWindowController()
            commitmentsWindowController?.window?.delegate = self
        }
        if let win = commitmentsWindowController?.window {
            win.center()
            activateAndPresent(win)
        }
    }

    func showWelcomeNotification() {
        showDashboard(item: .home)
    }

    func resetOnboardingAndRestart() {
        OnboardingStateStore.shared.resetProgress()
        AppRelauncher.relaunch()
    }
}
