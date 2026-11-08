//
//  AppInstallLocation.swift
//  EchoTune
//

import AppKit
import os
import Foundation

/// Detects an app running from a mounted disk image or another read-only
/// location. macOS ties Screen Recording grants to the app's location, so a
/// DMG copy re-prompts forever — installing to /Applications fixes it.
enum AppInstallLocation {
    static var isRunningFromDiskImage: Bool {
        let bundlePath = Bundle.main.bundleURL.path
        guard bundlePath.hasPrefix("/Volumes/") else { return false }
        return !FileManager.default.isWritableFile(atPath: Bundle.main.bundleURL.deletingLastPathComponent().path)
    }

    static func logLaunchContext() {
        PermissionsLog.logger.notice("launch path=\(Bundle.main.bundleURL.path, privacy: .public) diskImage=\(isRunningFromDiskImage, privacy: .public)")
    }

    static var installedBundleURL: URL? {
        let installed = URL(fileURLWithPath: "/Applications/EchoTune.app")
        return FileManager.default.fileExists(atPath: installed.path) ? installed : nil
    }

    /// Copies the running bundle to /Applications, then relaunches from there
    /// and quits this copy. Returns false when the copy fails (caller shows an
    /// error); on success the process terminates before returning.
    static func moveToApplicationsAndRelaunch() -> Bool {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        let destination = URL(fileURLWithPath: "/Applications/EchoTune.app")

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
        } catch {
            debugLog("❌ Move to Applications failed: \(error.localizedDescription)")
            return false
        }

        debugLog("📦 Moved EchoTune to Applications — relaunching installed copy")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [destination.path]
        do {
            try task.run()
        } catch {
            debugLog("❌ Failed to open installed copy: \(error.localizedDescription)")
            return false
        }

        NSApp.terminate(nil)
        return true
    }
}
