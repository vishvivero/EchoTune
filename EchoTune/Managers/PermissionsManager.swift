//
//  PermissionsManager.swift
//  EchoTune
//
//  Single source of truth for the three system permissions EchoTune needs:
//  microphone (capture speech), accessibility (insert text into other apps),
//  and screen recording (optional; used for context-aware transcription hints).
//
//  State refreshes whenever the app returns to the foreground, so coming
//  back from System Settings picks up newly granted permissions without a
//  relaunch. Accessibility is additionally watched on a short timer while
//  ungranted, because macOS offers no notification for that grant.
//

import Foundation
import AppKit
import AVFoundation
import ApplicationServices
import Combine
import ScreenCaptureKit

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    // MARK: - Published State

    @Published var hasMicrophonePermission = false
    @Published var hasAccessibilityPermission = false
    @Published var hasScreenRecordingPermission = false

    // MARK: - Internals

    private var cancellables = Set<AnyCancellable>()
    private var accessibilityWatch: DispatchSourceTimer?

    /// macOS deep links into the relevant Privacy & Security panes.
    private enum SettingsPane: String {
        case microphone = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case screenRecording = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

        func open() {
            guard let url = URL(string: rawValue) else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private init() {
        checkAllPermissions()

        // Re-evaluate every time the user returns to the app — typically
        // right after flipping a toggle in System Settings.
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkAllPermissions()
            }
            .store(in: &cancellables)

        if !hasAccessibilityPermission {
            beginAccessibilityWatch()
        }

        debugLog("✓ PermissionsManager ready — mic: \(hasMicrophonePermission), ax: \(hasAccessibilityPermission), screen: \(hasScreenRecordingPermission)")
    }

    // MARK: - Checking

    func checkAllPermissions() {
        checkMicrophonePermission()
        refreshAccessibilityState()
        refreshScreenRecordingState()
    }

    func checkMicrophonePermission() {
        let granted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        onMain { [weak self] in
            guard let self, self.hasMicrophonePermission != granted else { return }
            self.hasMicrophonePermission = granted
        }
    }

    private func refreshAccessibilityState() {
        let trusted = AXIsProcessTrusted()
        let becameGranted = trusted && !hasAccessibilityPermission
        onMain { [weak self] in
            guard let self, self.hasAccessibilityPermission != trusted else { return }
            self.hasAccessibilityPermission = trusted
        }

        if becameGranted {
            accessibilityWatch?.cancel()
            accessibilityWatch = nil
            debugLog("🔓 Accessibility granted")
            NotificationCenter.default.post(name: NSNotification.Name("AccessibilityPermissionGranted"), object: nil)
        }
    }

    private func refreshScreenRecordingState() {
        let granted = CGPreflightScreenCaptureAccess()
        onMain { [weak self] in
            guard let self, self.hasScreenRecordingPermission != granted else { return }
            self.hasScreenRecordingPermission = granted
        }
    }

    // MARK: - Requesting

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            onMain { [weak self] in
                self?.hasMicrophonePermission = true
            }
            completion(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicrophonePermission = granted
                    completion(granted)
                }
            }

        default:
            // Previously denied — the system won't re-prompt; send the user
            // to the pane where they can flip it themselves.
            SettingsPane.microphone.open()
            completion(false)
        }
    }

    func requestAccessibilityPermission() {
        guard !AXIsProcessTrusted() else {
            refreshAccessibilityState()
            return
        }

        // Trigger the native prompt only. The prompt's "Open System Settings"
        // button takes the user to the Accessibility pane, where macOS lists
        // EchoTune and they flip the switch. We deliberately do NOT deep-link
        // the pane ourselves: doing so showed a doubled dialog + pane for no
        // gain, and AXIsProcessTrustedWithOptions(prompt:) is what registers
        // the app in the list at all.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        beginAccessibilityWatch()
    }

    func requestScreenRecordingPermission() {
        guard !CGPreflightScreenCaptureAccess() else {
            refreshScreenRecordingState()
            return
        }

        // Two-step registration on macOS 14+:
        // 1. A real ScreenCaptureKit query creates the app's TCC record —
        //    this is what makes EchoTune appear in the Screen Recording pane.
        // 2. CGRequestScreenCaptureAccess fires the system prompt.
        if #available(macOS 14.0, *) {
            Task {
                _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            }
        }
        CGRequestScreenCaptureAccess()

        // macOS requires an app relaunch for this grant to take effect.
        SettingsPane.screenRecording.open()
    }

    /// Requests the two core permissions in sequence. Reports true only when
    /// both microphone and accessibility end up granted.
    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        requestMicrophonePermission { [weak self] micGranted in
            guard let self else {
                completion(false)
                return
            }
            self.requestAccessibilityPermission()
            completion(micGranted && AXIsProcessTrusted())
        }
    }

    // MARK: - Accessibility Grant Watch

    /// Polls the accessibility trust flag every couple of seconds until it
    /// flips on, then stops for good. Cheap call; bounded lifetime.
    private func beginAccessibilityWatch() {
        guard accessibilityWatch == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            self?.refreshAccessibilityState()
        }
        timer.resume()
        accessibilityWatch = timer
    }

    // MARK: - Helpers

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
