//
//  AutoSendService.swift
//  EchoTune
//
//  Phase 6A: Auto-Send After Paste
//  Automatically presses Enter/Return after pasting text
//

import Foundation
import AppKit
import CoreGraphics

class AutoSendService {
    static let shared = AutoSendService()

    private init() {
        debugLog("✅ AutoSendService initialized")
    }

    // MARK: - Auto-Send Methods

    /// Automatically sends/submits text after a delay
    /// - Parameters:
    ///   - delay: Delay in seconds before pressing Enter (default: 0.1)
    ///   - useShiftReturn: If true, presses Shift+Return instead of Return
    func sendAfterDelay(_ delay: TimeInterval = 0.1, useShiftReturn: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.pressReturn(withShift: useShiftReturn)
        }
    }

    /// Press Return or Shift+Return key
    /// - Parameter withShift: If true, presses Shift+Return
    private func pressReturn(withShift: Bool) {
        // Virtual key code for Return key (0x24)
        let returnKeyCode: CGKeyCode = 0x24

        if withShift {
            // Press Shift+Return (for new line in some apps)
            pressKeyWithModifier(keyCode: returnKeyCode, modifier: .maskShift)
        } else {
            // Press Return (for sending message)
            pressKey(keyCode: returnKeyCode)
        }

        debugLog("⏎ Auto-sent: \(withShift ? "Shift+Return" : "Return")")
    }

    /// Press a key without modifiers
    private func pressKey(keyCode: CGKeyCode) {
        // Key down event
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        keyDownEvent?.post(tap: .cghidEventTap)

        // Small delay between down and up
        usleep(10000) // 10ms

        // Key up event
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyUpEvent?.post(tap: .cghidEventTap)
    }

    /// Press a key with modifier (e.g., Shift)
    private func pressKeyWithModifier(keyCode: CGKeyCode, modifier: CGEventFlags) {
        // Key down event with modifier
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        keyDownEvent?.flags = modifier
        keyDownEvent?.post(tap: .cghidEventTap)

        // Small delay
        usleep(10000) // 10ms

        // Key up event
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        keyUpEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Context Detection

    /// Detect if current app benefits from auto-send
    func shouldAutoSend(for appIdentifier: String?) -> Bool {
        guard let appIdentifier = appIdentifier else { return false }

        // List of apps where auto-send is beneficial
        let autoSendApps: Set<String> = [
            // Chat/Messaging apps
            "com.tinyspeck.slackmacgap",           // Slack
            "com.hnc.Discord",                      // Discord
            "com.microsoft.teams2",                 // Microsoft Teams
            "us.zoom.xos",                          // Zoom
            "com.apple.iChat",                      // Messages
            "com.electron.whatsapp",                // WhatsApp
            "com.telegram.desktop",                 // Telegram

            // Browsers (for web chats)
            "com.google.Chrome",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",

            // Code/Terminal
            "com.apple.Terminal",
            "com.googlecode.iterm2",                // iTerm2
            "com.microsoft.VSCode",                 // VS Code

            // Other
            "com.linearmouse.LinearMouse"           // Linear (project management)
        ]

        return autoSendApps.contains(appIdentifier)
    }

    /// Get the frontmost application identifier
    func getFrontmostAppIdentifier() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return app.bundleIdentifier
    }

    // MARK: - Configuration Helper

    /// Check if auto-send should be triggered based on settings
    func shouldTriggerAutoSend() -> Bool {
        // Check if auto-send is enabled in settings
        let isEnabled = AppSettings.shared.autoSendEnabled

        guard isEnabled else {
            return false
        }

        // Check if current app is in the auto-send list
        let appIdentifier = getFrontmostAppIdentifier()
        return shouldAutoSend(for: appIdentifier)
    }
}
