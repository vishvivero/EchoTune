//
//  LaunchAtLoginManager.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import ServiceManagement
import Combine

class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool = false {
        didSet {
            setLaunchAtLogin(isEnabled)
        }
    }

    init() {
        // Check current status
        isEnabled = checkLaunchAtLoginStatus()
    }
    
    private func checkLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            // Use SMAppService for macOS 13+
            let status = SMAppService.mainApp.status
            debugLog("📍 Launch at login status: \(status)")
            return status == .enabled
        } else {
            // Use legacy approach for older macOS versions
            // Note: This doesn't actually check, it sets the value
            // For older macOS, we'd need to check login items differently
            return UserDefaults.standard.bool(forKey: "launchAtLoginEnabled")
        }
    }
    
    func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            // Use SMAppService for macOS 13+
            do {
                if enable {
                    if SMAppService.mainApp.status == .notRegistered {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                debugLog("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        } else {
            // Use legacy approach for older macOS versions
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            SMLoginItemSetEnabled(bundleId as CFString, enable)
        }
    }

    // Completion-based version for UI usage
    func setLaunchAtLogin(enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        if #available(macOS 13.0, *) {
            let currentStatus = SMAppService.mainApp.status

            do {
                if enabled {
                    // Only register if not already enabled
                    if currentStatus == .notRegistered {
                        try SMAppService.mainApp.register()
                        debugLog("✓ Registered for launch at login")
                    } else if currentStatus == .enabled {
                        debugLog("✓ Already registered for launch at login")
                    }
                } else {
                    // Only unregister if currently enabled
                    if currentStatus == .enabled {
                        try SMAppService.mainApp.unregister()
                        debugLog("✓ Unregistered from launch at login")
                    } else if currentStatus == .notRegistered {
                        debugLog("✓ Already not registered for launch at login")
                    } else if currentStatus == .notFound {
                        debugLog("⚠️ Service not found, cannot unregister")
                    }
                }

                // Update state and complete successfully
                DispatchQueue.main.async {
                    self.isEnabled = enabled
                    UserDefaults.standard.set(enabled, forKey: "launchAtLoginEnabled")
                    completion(.success(()))
                }
            } catch let error as NSError {
                debugLog("❌ Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
                debugLog("   Error domain: \(error.domain), code: \(error.code)")

                // For some errors, we might still want to update the UI state
                // This can happen if the system state is inconsistent
                if error.code == 1 { // Operation not permitted
                    debugLog("⚠️ Permission denied - updating local state only")
                    DispatchQueue.main.async {
                        self.isEnabled = enabled
                        UserDefaults.standard.set(enabled, forKey: "launchAtLoginEnabled")
                        completion(.success(()))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            SMLoginItemSetEnabled(bundleId as CFString, enabled)
            isEnabled = enabled
            completion(.success(()))
        }
    }

    // Get status description string
    func getStatusDescription() -> String {
        return isEnabled ? "Enabled" : "Disabled"
    }

    func toggleLaunchAtLogin() {
        isEnabled.toggle()
    }
}