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

    private init() {
        checkAllPermissions()
        startPermissionMonitoring()
        debugLog("✓ PermissionsManager initialized")
    }

    // Periodically check accessibility permission when not granted
    private func startPermissionMonitoring() {
        // Check every 2 seconds if accessibility permission is not granted
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Only check if permission is not currently granted
            if !self.hasAccessibilityPermission {
                self.checkAccessibilityPermission()
            }
        }
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
            return
        }

        // Reset accessibility permission for our bundle to clear stale entries,
        // then re-trigger the system prompt so macOS registers the app fresh.
        // This handles the case where the user previously dismissed the prompt
        // or where a different binary was registered.
        if let bundleId = Bundle.main.bundleIdentifier {
            let task = Process()
            task.launchPath = "/usr/bin/tccutil"
            task.arguments = ["reset", "Accessibility", bundleId]
            try? task.run()
            task.waitUntilExit()
            debugLog("   ✓ Reset TCC accessibility entry for \(bundleId)")
        }

        // Now show the system prompt — this will register the current binary fresh
        let promptOptions: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ]
        let _ = AXIsProcessTrustedWithOptions(promptOptions)
        debugLog("   ✓ System prompt triggered")

        // Also open System Settings as a fallback — user can use the + button
        // to manually add the app if the system prompt doesn't appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.openAccessibilitySettings()
        }
    }

    private func showAccessibilityInstructions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        EchoTune needs Accessibility permission to:
        • Insert transcribed text into other applications
        • Register global keyboard shortcuts for hands-free dictation

        Steps:
        1. Click "Open System Settings" below
        2. In the Privacy & Security section, scroll to Accessibility
        3. Find "EchoTune" in the list and toggle it ON
        4. Return to EchoTune and click "Refresh Status" in Privacy Settings

        Note: After granting permission, you may need to restart EchoTune.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    func openAccessibilitySettings() {
        // Use the correct method based on macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        // Try opening Accessibility settings with the app's bundle identifier
        // This sometimes helps macOS recognize which app is requesting permission
        if let bundleId = Bundle.main.bundleIdentifier {
            debugLog("📦 Bundle ID: \(bundleId)")
            
            // For macOS 13+, try using the new System Settings format
            if osVersion.majorVersion >= 13 {
                if #available(macOS 13.0, *) {
                    // Try direct URL to accessibility settings
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                        
                        // Don't show dialog automatically - user will see if EchoTune appears or not
                        return
                    }
                }
            }
        }
        
        // Fallback for macOS 12 and earlier, or if new method fails
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
        ]
        
        for urlString in urlStrings {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                
                // Don't show dialog automatically
                return
            }
        }
        
        debugLog("⚠️ Could not open System Settings - please navigate manually to Privacy & Security → Accessibility")
    }

    // Helper method to show instructions if app doesn't appear (call manually if needed)
    func showManualAdditionInstructions() {
        let alert = NSAlert()
        alert.messageText = "Add EchoTune to Accessibility"
        alert.informativeText = """
        If EchoTune doesn't appear in the Accessibility list:

        1. Click the "+" button (if available) in System Settings
        2. Navigate to Applications folder
        3. Select EchoTune.app
        4. Enable the toggle next to EchoTune

        Note: If running from Xcode, you may need to build and run the release version.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        // Open Screen Recording settings
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
        ]

        for urlString in urlStrings {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }
        }

        debugLog("⚠️ Could not open System Settings - please navigate manually to Privacy & Security → Screen Recording")
    }

    // MARK: - Combined Check

    func allPermissionsGranted() -> Bool {
        return hasMicrophonePermission && hasAccessibilityPermission
    }

    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        // Request microphone first
        requestMicrophonePermission { [weak self] micGranted in
            guard let self = self else { return }

            if !micGranted {
                completion(false)
                return
            }

            // Then check/request accessibility
            if !self.hasAccessibilityPermission {
                self.requestAccessibilityPermission()
                // Accessibility requires manual grant, so we return false
                // User needs to enable it in System Settings
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // MARK: - UI Helpers

    func showPermissionsAlert() {
        let missingPermissions = getMissingPermissions()

        if missingPermissions.isEmpty {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Permissions Required"

        var message = "EchoTune needs the following permissions:\n\n"

        if !hasMicrophonePermission {
            message += "• Microphone - To record your voice\n"
        }

        if !hasAccessibilityPermission {
            message += "• Accessibility - To insert text into apps\n"
        }

        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Grant Permissions")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            requestAllPermissions { _ in }
        }
    }

    func getMissingPermissions() -> [String] {
        var missing: [String] = []

        if !hasMicrophonePermission {
            missing.append("Microphone")
        }

        if !hasAccessibilityPermission {
            missing.append("Accessibility")
        }

        if !hasScreenRecordingPermission {
            missing.append("Screen Recording (Recommended)")
        }

        return missing
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
