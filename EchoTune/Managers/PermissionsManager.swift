//
//  PermissionsManager.swift
//  EchoTune
//
//  Phase 2: Permission Management (Microphone & Accessibility)
//

import AVFoundation
import ApplicationServices
import AppKit
import SwiftUI
import Combine
import Carbon

class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    private static let accessibilityPollInterval: TimeInterval = 2.0

    private enum PrivacyPane {
        case accessibility
        case screenRecording

        var urlCandidates: [String] {
            switch self {
            case .accessibility:
                return [
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                    "x-apple.systempreferences:com.apple.preference.security?Privacy"
                ]
            case .screenRecording:
                return [
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
                    "x-apple.systempreferences:com.apple.preference.security?Privacy"
                ]
            }
        }

        var fallbackPathDescription: String {
            switch self {
            case .accessibility:
                return "Privacy & Security → Accessibility"
            case .screenRecording:
                return "Privacy & Security → Screen Recording"
            }
        }
    }

    // Microphone
    @Published var hasMicrophonePermission = false
    @Published var microphoneStatus: PermissionStatus = .notDetermined

    // Accessibility
    @Published var hasAccessibilityPermission = false
    @Published var accessibilityStatus: PermissionStatus = .notDetermined

    // Screen Recording
    @Published var hasScreenRecordingPermission = false
    @Published var screenRecordingStatus: PermissionStatus = .notDetermined

    // Track pending permission checks to avoid race conditions
    private var pendingAccessibilityCheck: DispatchWorkItem?

    // Timer for periodic permission checking
    private var permissionCheckTimer: Timer?

    private var foregroundObserver: NSObjectProtocol?

    private init() {
        checkAllPermissions()
        startPermissionMonitoring()
        startForegroundMonitoring()
        debugLog("✓ PermissionsManager initialized")
    }

    deinit {
        stopPermissionMonitoring()
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    // Periodically check accessibility permission when not granted
    private func startPermissionMonitoring() {
        guard permissionCheckTimer == nil else { return }

        // Check every 2 seconds if accessibility permission is not granted
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: Self.accessibilityPollInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Only check if permission is not currently granted
            if !self.hasAccessibilityPermission {
                self.checkAccessibilityPermission()
            } else {
                self.stopPermissionMonitoring()
            }
        }
    }

    private func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    private func updateAccessibilityMonitoring() {
        if hasAccessibilityPermission {
            stopPermissionMonitoring()
        } else {
            startPermissionMonitoring()
        }
    }

    private func startForegroundMonitoring() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            debugLog("🔄 App became active - refreshing permission state")
            self?.checkAllPermissions()
        }
    }

    var accessibilityInlineInstructions: String {
        "System Settings opens directly to Accessibility. Turn on EchoTune, authenticate if macOS asks, then return here."
    }

    var screenRecordingInlineInstructions: String {
        "System Settings opens directly to Screen Recording. Enable EchoTune there, then quit and reopen the app only if macOS asks you to."
    }

    // MARK: - Check All Permissions

    func checkAllPermissions() {
        debugLog("🔄 Checking all permissions...")
        checkMicrophonePermission()
        checkScreenRecordingPermission()

        // Cancel any pending accessibility checks to avoid race conditions
        pendingAccessibilityCheck?.cancel()
        pendingAccessibilityCheck = nil

        // Check accessibility immediately with API verification
        // The checkAccessibilityPermission method uses API access which is definitive
        checkAccessibilityPermission()

        // Single re-check after short delay only if permission appears to be missing
        // This handles the case where permission was just granted in System Settings
        let recheckWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // Only re-check if we still think permission is not granted
            // This avoids overwriting correct "granted" status with delayed checks
            if !self.hasAccessibilityPermission {
                debugLog("🔄 Re-checking accessibility (initial check showed not granted)...")
                self.checkAccessibilityPermission()
            } else {
                debugLog("   ✓ Permission already verified as granted - skipping re-check")
            }
            self.pendingAccessibilityCheck = nil
        }

        pendingAccessibilityCheck = recheckWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: recheckWorkItem)
    }

    // MARK: - Microphone Permission

    func checkMicrophonePermission() {
        let status = AVAudioApplication.shared.recordPermission

        switch status {
        case .granted:
            hasMicrophonePermission = true
            microphoneStatus = .granted
            debugLog("✓ Microphone: Granted")

        case .denied:
            hasMicrophonePermission = false
            microphoneStatus = .denied
            debugLog("❌ Microphone: Denied")

        case .undetermined:
            hasMicrophonePermission = false
            microphoneStatus = .notDetermined
            debugLog("⏳ Microphone: Not determined")

        @unknown default:
            hasMicrophonePermission = false
            microphoneStatus = .notDetermined
        }
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasMicrophonePermission = granted
                self?.microphoneStatus = granted ? .granted : .denied

                debugLog(granted ? "✓ Microphone permission granted" : "❌ Microphone permission denied")
                completion(granted)
            }
        }
    }

    // MARK: - Accessibility Permission

    func checkAccessibilityPermission() {
        // Use AXIsProcessTrustedWithOptions (prompt: false) for a non-prompting but fresh check.
        // AXIsProcessTrusted() can be cached by macOS at process level, but
        // AXIsProcessTrustedWithOptions re-queries the TCC database each call.
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ]
        let trusted = AXIsProcessTrustedWithOptions(options)

        // Secondary verification: actually try to use the accessibility API.
        // This catches edge cases where TCC says granted but the API doesn't work yet
        // (e.g., right after toggling, before macOS propagates the change).
        var apiWorks = false
        if trusted {
            if let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
                let appElement = AXUIElementCreateApplication(finder.processIdentifier)
                var role: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &role)
                apiWorks = (result == .success)
            }
        }

        // Trust the TCC check as primary. API verification is just extra confidence.
        let finalStatus = trusted

        // Update on main thread
        DispatchQueue.main.async {
            let wasGranted = self.hasAccessibilityPermission
            let statusChanged = (wasGranted != finalStatus)

            self.hasAccessibilityPermission = finalStatus
            if finalStatus {
                self.accessibilityStatus = .granted
            } else {
                // When not trusted — check if we've previously prompted
                let hasRequestedBefore = UserDefaults.standard.bool(forKey: "hasRequestedAccessibilityPermission")
                self.accessibilityStatus = hasRequestedBefore ? .denied : .notDetermined
            }

            self.updateAccessibilityMonitoring()

            if statusChanged {
                debugLog("🔄 Accessibility status changed: \(wasGranted ? "granted" : "not granted") → \(finalStatus ? "granted" : "not granted")\(apiWorks ? " (API verified)" : "")")
                self.objectWillChange.send()

                // Automatically re-register keyboard shortcuts when permission is newly granted
                if !wasGranted && finalStatus {
                    debugLog("   🎹 Accessibility permission newly granted - re-registering keyboard shortcuts...")
                    NotificationCenter.default.post(name: NSNotification.Name("AccessibilityPermissionGranted"), object: nil)
                }
            }
        }
    }

    func requestAccessibilityPermission() {
        debugLog("🔐 Requesting accessibility permission...")
        UserDefaults.standard.set(true, forKey: "hasRequestedAccessibilityPermission")

        // Check current status first
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ]
        let alreadyTrusted = AXIsProcessTrustedWithOptions(options)

        if alreadyTrusted {
            debugLog("✅ Accessibility permission already granted!")
            self.hasAccessibilityPermission = true
            self.accessibilityStatus = .granted
            self.updateAccessibilityMonitoring()
            NotificationCenter.default.post(name: NSNotification.Name("AccessibilityPermissionGranted"), object: nil)
            return
        }

        // Now show the system prompt — this will register the current binary fresh
        let promptOptions: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ]
        let _ = AXIsProcessTrustedWithOptions(promptOptions)
        debugLog("   ✓ System prompt triggered")

        // Open the exact settings pane so the EchoTune toggle is visible immediately.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.openAccessibilitySettings()
        }
    }

    func openAccessibilitySettings() {
        openPrivacyPane(.accessibility)
    }

    // MARK: - Screen Recording Permission

    func checkScreenRecordingPermission() {
        // Use CGPreflightScreenCaptureAccess (macOS 15+) to check without triggering a prompt.
        // On older macOS, use CGWindowListCopyWindowInfo which doesn't trigger the prompt
        // (only CGWindowListCreateImage / CGDisplayCreateImage trigger it).

        debugLog("🔍 Checking Screen Recording Permission (non-intrusive)")

        if #available(macOS 15.0, *) {
            // macOS 15+: preflight check — no prompt triggered
            let hasPermission = CGPreflightScreenCaptureAccess()
            debugLog("   CGPreflightScreenCaptureAccess: \(hasPermission)")

            DispatchQueue.main.async {
                self.hasScreenRecordingPermission = hasPermission
                self.screenRecordingStatus = hasPermission ? .granted : .notDetermined
            }
        } else {
            // macOS 14 and earlier: check window list info only (no capture attempt)
            // CGWindowListCopyWindowInfo does NOT trigger the permission prompt.
            // Without permission, window names/owner details for other apps are redacted.
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

            let ourBundleID = Bundle.main.bundleIdentifier ?? ""
            let userAppBundles = [
                "com.apple.finder", "com.google.Chrome", "com.apple.Safari",
                "com.microsoft.VSCode", "com.apple.mail", "org.mozilla.firefox",
                "com.apple.Notes", "com.apple.TextEdit"
            ]

            var foundUserAppWindows = 0
            for window in windows {
                if let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 {
                    let app = NSRunningApplication(processIdentifier: ownerPID)
                    if let bundleID = app?.bundleIdentifier,
                       bundleID != ourBundleID,
                       userAppBundles.contains(bundleID) {
                        foundUserAppWindows += 1
                    }
                }
            }

            let hasPermission = foundUserAppWindows >= 2
            debugLog("   Window info check: found \(foundUserAppWindows) user app windows → \(hasPermission ? "GRANTED" : "NOT GRANTED")")

            DispatchQueue.main.async {
                self.hasScreenRecordingPermission = hasPermission
                self.screenRecordingStatus = hasPermission ? .granted : .notDetermined
            }
        }
    }

    func requestScreenRecordingPermission() {
        debugLog("🔐 Requesting screen recording permission...")

        // macOS 15+: Use CGRequestScreenCaptureAccess() which shows the native system prompt
        // and registers the app in one step. On older macOS, use CGDisplayCreateImage
        // (CGWindowListCopyWindowInfo does NOT trigger registration).
        if #available(macOS 15.0, *) {
            let granted = CGRequestScreenCaptureAccess()
            debugLog("   CGRequestScreenCaptureAccess: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    self.hasScreenRecordingPermission = true
                    self.screenRecordingStatus = .granted
                }
                return
            }
        } else {
            // macOS 14 and earlier: Attempt an actual screen capture to trigger registration
            // This is what forces macOS to add EchoTune to the Screen Recording list
            if let displayID = CGMainDisplayID() as CGDirectDisplayID? {
                let _ = CGDisplayCreateImage(displayID)
                debugLog("   ✓ Triggered CGDisplayCreateImage to register for screen recording")
            }
        }

        // Open System Settings directly — the system prompt (macOS 15+) or the capture
        // attempt (older) already registered the app, user just needs to toggle it on
        openScreenRecordingSettings()
    }

    func openScreenRecordingSettings() {
        openPrivacyPane(.screenRecording)
    }

    @discardableResult
    private func openPrivacyPane(_ pane: PrivacyPane) -> Bool {
        for urlString in pane.urlCandidates {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                debugLog("⚙️ Opened System Settings pane: \(urlString)")
                return true
            }
        }

        debugLog("⚠️ Could not open System Settings - please navigate manually to \(pane.fallbackPathDescription)")
        return false
    }

    // MARK: - Combined Check

    func allPermissionsGranted() -> Bool {
        return hasMicrophonePermission && hasAccessibilityPermission
    }

    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        requestMicrophonePermission { [weak self] microphoneGranted in
            guard let self = self else { return }

            guard microphoneGranted else {
                completion(false)
                return
            }

            if self.hasAccessibilityPermission {
                completion(true)
            } else {
                self.requestAccessibilityPermission()
                completion(false)
            }
        }
    }

    // Check if we have core permissions (mic + accessibility)
    // Screen recording is optional but recommended
    func hasCorePermissions() -> Bool {
        return hasMicrophonePermission && hasAccessibilityPermission
    }
}

// MARK: - Permission Status

enum PermissionStatus {
    case notDetermined
    case granted
    case denied

    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .granted: return "Granted"
        case .denied: return "Denied"
        }
    }

    var iconName: String {
        switch self {
        case .notDetermined: return "questionmark.circle"
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notDetermined: return .orange
        case .granted: return .green
        case .denied: return .red
        }
    }
}
