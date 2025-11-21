//
//  UpdateManager.swift
//  EchoTune
//
//  Phase 6C: Sparkle Auto-Update Integration
//  Manages automatic app updates using Sparkle framework
//

import Foundation
import AppKit
import Combine

/// Manages automatic updates for EchoTune
/// Note: Requires Sparkle framework to be integrated via Swift Package Manager
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var canCheckForUpdates: Bool = true
    @Published var automaticUpdatesEnabled: Bool = true

    // Sparkle updater instance (will be nil until Sparkle framework is added)
    // private var updater: SPUUpdater?

    private let updateFeedURL = "https://echotune.app/appcast.xml" // Placeholder URL
    private let checkInterval: TimeInterval = 86400 // 24 hours

    private init() {
        loadSettings()
        // Note: Actual Sparkle integration requires adding the framework
        // via Swift Package Manager: https://github.com/sparkle-project/Sparkle
        print("📦 UpdateManager initialized (Sparkle framework pending)")
    }

    // MARK: - Public API

    /// Check for updates manually
    func checkForUpdates() {
        print("🔍 Checking for updates...")

        // TODO: Implement with Sparkle framework
        // updater?.checkForUpdates()

        NotificationManager.shared.showNotification(
            title: "Update Check",
            body: "Checking for updates... (Sparkle integration pending)",
            sound: false
        )
    }

    /// Check for updates in background (silent)
    func checkForUpdatesInBackground() {
        guard automaticUpdatesEnabled else { return }

        print("🔍 Checking for updates in background...")

        // TODO: Implement with Sparkle framework
        // updater?.checkForUpdatesInBackground()
    }

    /// Enable/disable automatic updates
    func setAutomaticUpdates(enabled: Bool) {
        automaticUpdatesEnabled = enabled
        saveSettings()

        print("⚙️ Automatic updates \(enabled ? "enabled" : "disabled")")

        // TODO: Configure Sparkle
        // updater?.automaticallyChecksForUpdates = enabled
    }

    /// Get current app version
    func getCurrentVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "Unknown"
    }

    /// Get update feed URL
    func getUpdateFeedURL() -> String {
        return updateFeedURL
    }

    // MARK: - Update Information

    struct UpdateInfo: Codable {
        let version: String
        let releaseDate: Date
        let releaseNotes: String
        let downloadURL: String
        let fileSize: Int64
        let minimumSystemVersion: String
    }

    /// Fetch update information from feed (manual implementation)
    func fetchUpdateInfo() async throws -> UpdateInfo? {
        guard let url = URL(string: updateFeedURL) else {
            throw UpdateError.invalidURL
        }

        // TODO: Parse Sparkle appcast XML
        // For now, return nil (no updates available)
        return nil
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        UserDefaults.standard.set(automaticUpdatesEnabled, forKey: "automaticUpdatesEnabled")
    }

    private func loadSettings() {
        automaticUpdatesEnabled = UserDefaults.standard.bool(forKey: "automaticUpdatesEnabled")

        // Default to enabled
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            automaticUpdatesEnabled = true
            saveSettings()
        }
    }

    // MARK: - Error Types

    enum UpdateError: LocalizedError {
        case invalidURL
        case downloadFailed
        case installationFailed
        case noUpdatesAvailable

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid update feed URL"
            case .downloadFailed:
                return "Failed to download update"
            case .installationFailed:
                return "Failed to install update"
            case .noUpdatesAvailable:
                return "No updates available"
            }
        }
    }
}

// MARK: - Sparkle Integration Guide

/*
 To fully integrate Sparkle Auto-Updates:

 1. Add Sparkle via Swift Package Manager:
    - In Xcode: File > Add Packages...
    - URL: https://github.com/sparkle-project/Sparkle
    - Version: 2.x (latest)

 2. Import Sparkle in this file:
    import Sparkle

 3. Initialize SPUStandardUpdaterController:
    private let updaterController: SPUStandardUpdaterController

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.automaticallyChecksForUpdates = true
        updaterController.updater.updateCheckInterval = checkInterval
    }

 4. Implement update methods:
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }

 5. Create appcast.xml feed:
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
        <channel>
            <title>EchoTune Updates</title>
            <link>https://echotune.app/appcast.xml</link>
            <description>Updates for EchoTune</description>
            <item>
                <title>Version 1.0.1</title>
                <sparkle:version>1.0.1</sparkle:version>
                <sparkle:releaseNotesLink>https://echotune.app/releasenotes/1.0.1.html</sparkle:releaseNotesLink>
                <pubDate>Mon, 19 Nov 2025 12:00:00 +0000</pubDate>
                <enclosure url="https://echotune.app/downloads/EchoTune-1.0.1.zip"
                           sparkle:version="1.0.1"
                           type="application/octet-stream"
                           length="12345678"
                           sparkle:edSignature="..." />
                <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            </item>
        </channel>
    </rss>

 6. Add SUFeedURL to Info.plist:
    <key>SUFeedURL</key>
    <string>https://echotune.app/appcast.xml</string>

    <key>SUEnableAutomaticChecks</key>
    <true/>

    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>

 7. Sign updates with EdDSA:
    - Generate signing keys: ./bin/generate_keys
    - Sign update: ./bin/sign_update EchoTune-1.0.1.zip
    - Add public key to Info.plist:
      <key>SUPublicEDKey</key>
      <string>YOUR_PUBLIC_KEY_HERE</string>

 8. Host appcast.xml and updates on your server

 9. Test updates:
    - Increment version in Info.plist
    - Build and archive
    - Create DMG
    - Sign DMG
    - Upload to server
    - Update appcast.xml
    - Test auto-update flow

 For more information: https://sparkle-project.org/documentation/
*/
