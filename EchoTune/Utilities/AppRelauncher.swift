//
//  AppRelauncher.swift
//  EchoTune
//

import AppKit

enum AppRelauncher {
    /// Quits and reopens the app. Used when a macOS permission (Screen
    /// Recording) only takes effect for this process after a relaunch.
    static func relaunch() {
        debugLog("🔄 Relaunching EchoTune to activate Screen Recording…")
        let target = AppInstallLocation.isRunningFromDiskImage
            ? (AppInstallLocation.installedBundleURL ?? Bundle.main.bundleURL)
            : Bundle.main.bundleURL

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [target.path]

        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            debugLog("❌ Failed to relaunch: \(error.localizedDescription)")
        }
    }
}
