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
import os

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    // MARK: - Published State

    @Published var hasMicrophonePermission = false
    @Published var hasAccessibilityPermission = false
    @Published var hasScreenRecordingPermission = false

    /// True once an actual ScreenCaptureKit query succeeds — the feature works
    /// right now. TCC's toggle (preflight) can be on while this stays false for
    /// the current process; that resolves on the next launch with no prompt.
    @Published var screenCaptureActive = false

    /// Granted but not yet usable by this process. Settings shows a passive
    /// note; onboarding never nags about it.
    @Published var screenCaptureActivatesAfterRelaunch = false

    // MARK: - Internals

    private var cancellables = Set<AnyCancellable>()
    private var accessibilityWatch: DispatchSourceTimer?
    private var screenRecordingWatch: DispatchSourceTimer?
    private var screenCaptureProbeTask: Task<Void, Never>?
    private var screenRecordingPromptShown = false

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
        #if DEBUG
        // UI verification hook: this machine already has Screen Recording
        // granted, so the post-grant states can't be reached naturally.
        if ProcessInfo.processInfo.arguments.contains("--ui-test-force-screen-inactive") {
            screenCaptureActivatesAfterRelaunch = true
        }
        #endif

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
        if !hasScreenRecordingPermission {
            beginScreenRecordingWatch()
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
        PermissionsLog.logger.notice("screen preflight=\(granted, privacy: .public)")
        onMain { [weak self] in
            guard let self, self.hasScreenRecordingPermission != granted else { return }
            self.hasScreenRecordingPermission = granted
        }

        if granted {
            screenRecordingWatch?.cancel()
            screenRecordingWatch = nil
            scheduleScreenCaptureProbe()
        } else {
            screenCaptureProbeTask?.cancel()
            screenCaptureProbeTask = nil
            onMain { [weak self] in
                self?.screenCaptureActive = false
                self?.screenCaptureActivatesAfterRelaunch = false
            }
            beginScreenRecordingWatch()
        }
    }

    /// Screenshot permission grants can take a moment to reach this process.
    /// Retry a few times before concluding the feature isn't live yet; the
    /// result only drives a passive Settings note — onboarding never asks the
    /// user to restart.
    private func scheduleScreenCaptureProbe() {
        guard screenCaptureProbeTask == nil, !screenCaptureActive else { return }

        screenCaptureProbeTask = Task { [weak self] in
            let delays: [UInt64] = [0, 2, 5, 10, 20]
            for delay in delays {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                }
                if Task.isCancelled { return }
                let live = await ScreenContextManager.grantIsActiveWithoutRelaunch()
                PermissionsLog.logger.notice("screen live probe attempt=\(delay, privacy: .public)s result=\(live, privacy: .public)")
                if live {
                    self?.onMain {
                        self?.screenCaptureActive = true
                        self?.screenCaptureActivatesAfterRelaunch = false
                    }
                    debugLog("🖥️ Screen Recording is live — screen context enabled")
                    self?.screenCaptureProbeTask = nil
                    return
                }
            }
            self?.onMain {
                self?.screenCaptureActive = false
                self?.screenCaptureActivatesAfterRelaunch = true
            }
            debugLog("🖥️ Screen Recording granted but not active for this process — will enable on next launch")
            PermissionsLog.logger.notice("screen granted but inactive for this process; activates next launch")
            self?.screenCaptureProbeTask = nil
        }
    }

    // MARK: - Requesting

    /// Requests microphone access only when macOS has not asked before.
    ///
    /// This is used after onboarding as a first-launch safety net. It must not
    /// open System Settings for a previously denied permission: macOS will not
    /// show the native prompt again, and silently opening Settings on launch is
    /// surprising. The explicit Settings button continues to use
    /// requestMicrophonePermission(), which handles that denied case.
    func requestMicrophonePermissionIfNeeded() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
            checkMicrophonePermission()
            return
        }

        requestMicrophonePermission { granted in
            debugLog(granted ? "🎙️ Microphone permission granted" : "🎙️ Microphone permission not granted")
        }
    }

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

        // ScreenCaptureKit is the only path used here: its first query
        // registers EchoTune in System Settings and triggers the system
        // prompt. We deliberately avoid CGRequestScreenCaptureAccess, whose
        // legacy flow is what makes macOS demand a quit-and-reopen.
        if !screenRecordingPromptShown {
            screenRecordingPromptShown = true
            Task {
                _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                refreshScreenRecordingState()
            }
        } else {
            // The prompt was already answered or dismissed — the pane is the
            // only way left to grant it.
            SettingsPane.screenRecording.open()
        }

        beginScreenRecordingWatch()
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

    /// Same pattern for Screen Recording: the user may flip the toggle in
    /// System Settings without ever refocusing EchoTune (menu-bar usage), so
    /// a poll — not didBecomeActive — is what catches the grant.
    private func beginScreenRecordingWatch() {
        guard screenRecordingWatch == nil, !CGPreflightScreenCaptureAccess() else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            self?.refreshScreenRecordingState()
        }
        timer.resume()
        screenRecordingWatch = timer
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
