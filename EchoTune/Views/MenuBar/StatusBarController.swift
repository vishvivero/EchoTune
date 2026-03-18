//
//  StatusBarController.swift
//  EchoTune
//
//  Phase 1 & 5: Status Bar (Menu Bar) Controller with Quick Actions
//

import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let brandImageSize = NSSize(width: 16, height: 16)

    init() {
        setupStatusBar()
        setupMenu()

        // Assign menu to status item after both are created
        statusItem.menu = menu

        debugLog("✓ Status bar initialized")
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = statusImage(for: .idle)
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            statusItem.length = 28
            debugLog("✓ Status bar button created")

            // Set tooltip for discoverability
            button.toolTip = "EchoTune - Click for menu, or press Control to record"
        } else {
            debugLog("❌ Failed to create status bar button")
        }
    }

    private func setupMenu() {
        menu = NSMenu()

        // SECTION 1: Recording Controls
        // Start/Stop Recording (with current state)
        let recordingState = AppCoordinator.shared.appState.recordingState
        let isRecording = recordingState == .recording
        let recordingTitle = isRecording ? "⏹ Stop Recording (⌃)" : "⏺ Start Recording (⌃)"
        let recordingItem = NSMenuItem(
            title: recordingTitle,
            action: #selector(quickTranscribe),
            keyEquivalent: ""
        )
        recordingItem.target = self
        menu.addItem(recordingItem)

        menu.addItem(NSMenuItem.separator())

        // SECTION 2: Last Transcript Actions
        let lastTranscript = TranscriptionHistoryManager.shared.transcriptions.first

        // Copy Last Transcript
        let copyLastItem = NSMenuItem(
            title: "Copy Last Transcript",
            action: #selector(copyLastTranscript),
            keyEquivalent: "c"
        )
        copyLastItem.keyEquivalentModifierMask = [.command, .shift]
        copyLastItem.target = self
        if lastTranscript == nil {
            copyLastItem.isEnabled = false
        }
        menu.addItem(copyLastItem)

        // Recent Transcriptions submenu
        let recentItem = NSMenuItem(title: "Recent Transcriptions", action: nil, keyEquivalent: "")
        let recentSubmenu = NSMenu()

        let recentTranscripts = Array(TranscriptionHistoryManager.shared.transcriptions.prefix(5))

        if recentTranscripts.isEmpty {
            let emptyItem = NSMenuItem(title: "No transcriptions yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            recentSubmenu.addItem(emptyItem)
        } else {
            for (index, transcript) in recentTranscripts.enumerated() {
                let preview = transcript.text.count > 40 ? String(transcript.text.prefix(40)) + "..." : transcript.text
                let transcriptItem = NSMenuItem(
                    title: preview,
                    action: #selector(copyRecentTranscript(_:)),
                    keyEquivalent: ""
                )
                transcriptItem.target = self
                transcriptItem.tag = index
                transcriptItem.toolTip = "Click to copy: \(transcript.text)"
                recentSubmenu.addItem(transcriptItem)
            }

            recentSubmenu.addItem(NSMenuItem.separator())

            let viewAllItem = NSMenuItem(
                title: "View All History...",
                action: #selector(showTranscriptionHistory),
                keyEquivalent: ""
            )
            viewAllItem.target = self
            recentSubmenu.addItem(viewAllItem)
        }

        recentItem.submenu = recentSubmenu
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        // SECTION 3: Statistics
        let statisticsItem = NSMenuItem(title: "Statistics", action: nil, keyEquivalent: "")
        let statisticsSubmenu = NSMenu()

        let stats = AnalyticsManager.shared.getStatistics()
        let todayStats = AnalyticsManager.shared.getDailyStats(for: Date())

        let todayItem = NSMenuItem(
            title: "Today: \(todayStats?.transcriptionCount ?? 0) transcriptions",
            action: nil,
            keyEquivalent: ""
        )
        todayItem.isEnabled = false
        statisticsSubmenu.addItem(todayItem)

        let totalItem = NSMenuItem(
            title: "Total: \(stats.totalWords) words",
            action: nil,
            keyEquivalent: ""
        )
        totalItem.isEnabled = false
        statisticsSubmenu.addItem(totalItem)

        statisticsSubmenu.addItem(NSMenuItem.separator())

        let viewDetailsItem = NSMenuItem(
            title: "View Details...",
            action: #selector(showStatistics),
            keyEquivalent: ""
        )
        viewDetailsItem.target = self
        statisticsSubmenu.addItem(viewDetailsItem)

        statisticsItem.submenu = statisticsSubmenu
        menu.addItem(statisticsItem)

        menu.addItem(NSMenuItem.separator())

        // SECTION 4: Settings & Support
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        // Send Feedback
        let feedbackItem = NSMenuItem(
            title: "Send Feedback...",
            action: #selector(sendFeedback),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        menu.addItem(feedbackItem)

        menu.addItem(NSMenuItem.separator())

        if shouldShowResetOnboarding {
            let resetItem = NSMenuItem(
                title: "Reset Onboarding...",
                action: #selector(resetOnboarding),
                keyEquivalent: ""
            )
            resetItem.target = self
            menu.addItem(resetItem)
            menu.addItem(NSMenuItem.separator())
        }

        // SECTION 6: About & Quit
        // About
        let aboutItem = NSMenuItem(
            title: "About EchoTune",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit EchoTune",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // Phase 5: Update menu dynamically
    func updateMenu() {
        setupMenu()
        statusItem.menu = menu
    }

    func updateIcon(for state: RecordingState) {
        guard let button = statusItem.button else { return }

        button.image = statusImage(for: state)
        button.toolTip = "EchoTune - \(state.description)"

        // Add subtle animation for recording state
        if case .recording = state {
            animateIcon(button)
        }
    }

    private var shouldShowResetOnboarding: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "internalTestingMode") ||
            ProcessInfo.processInfo.arguments.contains("--internal-testing")
        #endif
    }

    private func statusImage(for state: RecordingState) -> NSImage? {
        guard let baseImage = brandBaseImage() else {
            return fallbackSymbolImage(for: state)
        }

        switch state {
        case .idle:
            return baseImage
        case .recording:
            return brandedBadgeImage(baseImage: baseImage, badgeColor: .systemRed, badgeInset: 1.5)
        case .processing, .loadingModel:
            return brandedBadgeImage(baseImage: baseImage, badgeColor: .systemBlue, badgeInset: 2.5)
        case .error:
            return brandedBadgeImage(baseImage: baseImage, badgeColor: .systemOrange, badgeInset: 1.5)
        }
    }

    private func brandBaseImage() -> NSImage? {
        guard let image = NSImage(named: "MenuBarIcon")?.copy() as? NSImage else {
            debugLog("⚠️ Custom logo not found, using waveform icon")
            return nil
        }

        image.isTemplate = true
        image.size = brandImageSize
        return image
    }

    private func fallbackSymbolImage(for state: RecordingState) -> NSImage? {
        let image = NSImage(systemSymbolName: state.iconName, accessibilityDescription: state.description)
        image?.isTemplate = true
        return image
    }

    private func brandedBadgeImage(baseImage: NSImage, badgeColor: NSColor, badgeInset: CGFloat) -> NSImage {
        let composedImage = NSImage(size: brandImageSize)
        composedImage.lockFocus()

        baseImage.draw(in: NSRect(origin: .zero, size: brandImageSize))

        let badgeDiameter: CGFloat = 5.5
        let badgeRect = NSRect(
            x: brandImageSize.width - badgeDiameter - badgeInset,
            y: badgeInset,
            width: badgeDiameter,
            height: badgeDiameter
        )

        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1.0, dy: -1.0)).fill()

        badgeColor.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        composedImage.unlockFocus()
        composedImage.isTemplate = false
        composedImage.size = brandImageSize
        return composedImage
    }

    private func animateIcon(_ button: NSStatusBarButton) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            button.animator().alphaValue = 0.5
        } completionHandler: {
            button.alphaValue = 1.0
        }
    }

    // MARK: - Menu Actions (Phase 5)

    @objc private func quickTranscribe() {
        AppCoordinator.shared.toggleDictation()
    }

    @objc private func copyLastTranscript() {
        guard let lastTranscript = TranscriptionHistoryManager.shared.transcriptions.first else {
            debugLog("❌ No transcripts available")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastTranscript.text, forType: .string)

        debugLog("✓ Copied last transcript to clipboard: \(lastTranscript.text.prefix(50))...")

        // Show subtle notification
        NotificationManager.shared.showNotification(
            title: "Transcript Copied",
            body: "Last transcript copied to clipboard",
            sound: false
        )
    }

    @objc private func copyRecentTranscript(_ sender: NSMenuItem) {
        let index = sender.tag
        let recentTranscripts = Array(TranscriptionHistoryManager.shared.transcriptions.prefix(5))

        guard index < recentTranscripts.count else {
            debugLog("❌ Invalid transcript index")
            return
        }

        let transcript = recentTranscripts[index]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript.text, forType: .string)

        debugLog("✓ Copied transcript to clipboard: \(transcript.text.prefix(50))...")

        // Show subtle notification
        NotificationManager.shared.showNotification(
            title: "Transcript Copied",
            body: "Copied to clipboard",
            sound: false
        )
    }

    @objc private func showTranscriptionHistory() {
        // Open settings to History tab
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showSettings()
            // Post notification to switch to history tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToSettingsTab"),
                    object: nil,
                    userInfo: ["tab": "history"]
                )
            }
        }
    }

    @objc private func showStatistics() {
        // Show detailed statistics in settings
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showSettings()
            // Post notification to switch to statistics tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToSettingsTab"),
                    object: nil,
                    userInfo: ["tab": "statistics"]
                )
            }
        }
    }

    @objc private func showSettings() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showSettings()
        }
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }

    @objc private func sendFeedback() {
        // Open email client with pre-filled feedback email
        let subject = "EchoTune Feedback"
        let body = """
        Please share your feedback below:

        ---
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        OS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        ---
        """

        if let emailURL = createEmailURL(to: "hi@echotune.app", subject: subject, body: body) {
            NSWorkspace.shared.open(emailURL)
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "EchoTune"
        alert.informativeText = """
        Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")

        AI-powered voice dictation for Mac.
        100% private, all processing on your device.

        © \(Calendar.current.component(.year, from: Date())) EchoTune
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func resetOnboarding() {
        let alert = NSAlert()
        alert.messageText = "Reset Onboarding"
        alert.informativeText = """
        This will reset the onboarding flow and restart the app.

        Use this to:
        • Re-test permissions setup
        • Review the welcome experience
        • Troubleshoot accessibility issues

        The app will restart and show the welcome screen again.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset & Restart")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            OnboardingStateStore.shared.resetProgress()
            debugLog("🔄 Onboarding reset - restarting app...")

            // Restart the app
            let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [path]
            task.launch()
            NSApp.terminate(nil)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    private func createEmailURL(to: String, subject: String, body: String) -> URL? {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)"
        return URL(string: urlString)
    }
}
