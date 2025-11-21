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
        print("✓ PermissionsManager initialized")
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
        print("🔄 Checking all permissions...")
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
                print("🔄 Re-checking accessibility (initial check showed not granted)...")
                self.checkAccessibilityPermission()
            } else {
                print("   ✓ Permission already verified as granted - skipping re-check")
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
            print("✓ Microphone: Granted")

        case .denied:
            hasMicrophonePermission = false
            microphoneStatus = .denied
            print("❌ Microphone: Denied")

        case .undetermined:
            hasMicrophonePermission = false
            microphoneStatus = .notDetermined
            print("⏳ Microphone: Not determined")

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

                print(granted ? "✓ Microphone permission granted" : "❌ Microphone permission denied")
                completion(granted)
            }
        }
    }

    // MARK: - Accessibility Permission

    func checkAccessibilityPermission() {
        print("🔍 Checking accessibility permission status...")

        // Primary check: Use AXIsProcessTrusted() which should be reliable now that
        // we have NSAccessibilityUsageDescription in Info.plist
        let trusted = AXIsProcessTrusted()
        print("   AXIsProcessTrusted: \(trusted ? "Granted" : "Not granted")")

        // Verification: Try to access a system app's UI elements as a sanity check
        // This confirms that we actually have working accessibility permission
        var apiVerified = false
        if trusted {
            // Only verify if the flag says we're trusted
            if let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) {
                let pid = dock.processIdentifier
                let appElement = AXUIElementCreateApplication(pid)
                var role: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &role)

                if result == .success {
                    apiVerified = true
                    print("   ✓ API verification successful - permission is working")
                } else {
                    print("   ⚠️ API verification failed (error: \(result.rawValue)) - permission may not be working properly")
                }
            }
        }

        // Use the AXIsProcessTrusted() result as the authoritative answer
        // With NSAccessibilityUsageDescription properly set, this should be accurate
        let finalStatus = trusted

        // Update on main thread
        DispatchQueue.main.async {
            let wasGranted = self.hasAccessibilityPermission
            let statusChanged = (wasGranted != finalStatus)

            self.hasAccessibilityPermission = finalStatus
            self.accessibilityStatus = finalStatus ? .granted : .notDetermined

            if statusChanged {
                print("   🔄 Status changed: \(wasGranted ? "granted" : "not granted") → \(finalStatus ? "granted" : "not granted")")
                self.objectWillChange.send()

                // Automatically re-register keyboard shortcuts when permission is newly granted
                if !wasGranted && finalStatus {
                    print("   🎹 Accessibility permission newly granted - re-registering keyboard shortcuts...")
                    // Import needed - add notification post to trigger shortcut re-registration
                    NotificationCenter.default.post(name: NSNotification.Name("AccessibilityPermissionGranted"), object: nil)
                }
            }

            if finalStatus {
                print("✅ Accessibility: Granted\(apiVerified ? " (verified)" : "")")
            } else {
                print("❌ Accessibility: Not granted")
                print("   ℹ️ Please enable accessibility permission in System Settings")
            }
        }
    }

    func requestAccessibilityPermission() {
        print("🔐 Requesting accessibility permission...")
        print("   This will register EchoTune in System Settings...")

        // Step 1: Request with prompt option - CRITICAL for registration
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            print("✅ Accessibility permission already granted!")
            self.hasAccessibilityPermission = true
            self.accessibilityStatus = .granted
            return
        }

        // Step 2: Force registration by attempting to use accessibility APIs
        // This is CRITICAL - macOS only registers the app when it actually tries to use the APIs
        print("⏳ Attempting accessibility API calls to trigger registration...")

        DispatchQueue.global(qos: .userInitiated).async {
            // Attempt 1: Try to access Dock (always running)
            if let dock = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) {
                let pid = dock.processIdentifier
                let element = AXUIElementCreateApplication(pid)
                var role: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
                print("   ✓ Attempted to access Dock UI")
            }

            // Attempt 2: Try to access Finder
            if let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
                let pid = finder.processIdentifier
                let element = AXUIElementCreateApplication(pid)
                var role: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
                print("   ✓ Attempted to access Finder UI")
            }

            // Attempt 3: Try to create a CGEvent tap (this registers the app)
            let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            if let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: { (_, _, event, _) in Unmanaged.passRetained(event) },
                userInfo: nil
            ) {
                // Disable the tap immediately - we just needed to attempt creation
                CGEvent.tapEnable(tap: tap, enable: false)
                print("   ✓ Created test event tap (registration triggered)")
            } else {
                print("   ⚠️ Could not create event tap (expected without permission - still triggers registration)")
            }

            // Step 3: Wait for macOS to process, then open System Settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("   Opening System Settings...")
                print("   ℹ️  EchoTune should now appear in the Accessibility list")
                self.showAccessibilityInstructions()
            }
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
            print("📦 Bundle ID: \(bundleId)")
            
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
        
        print("⚠️ Could not open System Settings - please navigate manually to Privacy & Security → Accessibility")
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
        // Use the most reliable method: try to capture screen content
        // Without permission, CGWindowListCreateImage returns nil or empty data

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 Checking Screen Recording Permission")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Method 1: Check if we can get detailed window information
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        // Get our bundle identifier
        let ourBundleID = Bundle.main.bundleIdentifier ?? ""
        print("📦 Our Bundle ID: \(ourBundleID)")

        // Look for windows from well-known user applications (not system processes)
        // Without Screen Recording permission, we typically can't see these details
        let userAppBundles = [
            "com.apple.finder",           // Finder
            "com.google.Chrome",          // Chrome
            "com.apple.Safari",           // Safari
            "com.microsoft.VSCode",       // VS Code
            "com.apple.mail",             // Mail
            "org.mozilla.firefox",        // Firefox
            "com.apple.Notes",            // Notes
            "com.apple.TextEdit"          // TextEdit
        ]

        var foundUserAppWindows: [String] = []

        for window in windows {
            if let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 {
                let app = NSRunningApplication(processIdentifier: ownerPID)
                if let bundleID = app?.bundleIdentifier,
                   bundleID != ourBundleID,
                   userAppBundles.contains(bundleID) {
                    if let ownerName = window[kCGWindowOwnerName as String] as? String {
                        if !foundUserAppWindows.contains(ownerName) {
                            foundUserAppWindows.append(ownerName)
                            print("   ✓ Can see: \(ownerName)")
                        }
                    }
                }
            }
        }

        // Method 2: Try to capture a tiny screen region
        // This will fail silently without permission
        var hasPermissionViaCapture = false
        if let image = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) {
            // If we can create an image, we likely have permission
            hasPermissionViaCapture = image.width > 0 && image.height > 0
            print("   Screen capture test: \(hasPermissionViaCapture ? "✓ Success" : "✗ Failed")")
        } else {
            print("   Screen capture test: ✗ Failed (nil)")
        }

        // Combine both checks: either we found user app windows OR capture succeeded
        // We need STRONG evidence of permission, not weak
        let hasPermission = foundUserAppWindows.count >= 2 || hasPermissionViaCapture

        print("")
        print("📊 Results:")
        print("   - User app windows found: \(foundUserAppWindows.count)")
        print("   - Screen capture test: \(hasPermissionViaCapture ? "passed" : "failed")")
        print("   - Final result: \(hasPermission ? "GRANTED" : "NOT GRANTED")")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")

        DispatchQueue.main.async {
            self.hasScreenRecordingPermission = hasPermission
            self.screenRecordingStatus = hasPermission ? .granted : .notDetermined

            if hasPermission {
                print("✅ Screen Recording: Granted")
            } else {
                print("⚠️ Screen Recording: Not granted")
                print("   ℹ️ Screen recording permission is needed for browser compatibility")
            }
        }
    }

    func requestScreenRecordingPermission() {
        print("🔐 Requesting screen recording permission...")

        // Attempt to access screen content - this triggers the permission dialog
        _ = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)

        // Show instructions
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Recommended"
        alert.informativeText = """
        EchoTune works better with Screen Recording permission enabled.

        Benefits:
        • Better compatibility with web browsers (Chrome, Safari, etc.)
        • Improved text insertion in browser-based apps
        • Enhanced context awareness

        Steps:
        1. Click "Open System Settings" below
        2. Go to Privacy & Security → Screen Recording
        3. Find "EchoTune" and toggle it ON
        4. Restart EchoTune

        Note: Your screen content is NEVER stored or transmitted.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
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

        print("⚠️ Could not open System Settings - please navigate manually to Privacy & Security → Screen Recording")
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
