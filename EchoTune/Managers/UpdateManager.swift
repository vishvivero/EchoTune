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

#if canImport(Sparkle)
import Sparkle
#endif

/// Manages automatic updates for EchoTune
/// Fully integrated with Sparkle framework when available
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var updateAvailable: Bool = false
    @Published var latestVersion: String?
    @Published var releaseNotes: String?
    @Published var canCheckForUpdates: Bool = true
    @Published var automaticUpdatesEnabled: Bool = true
    @Published var isCheckingForUpdates: Bool = false
    @Published var lastCheckDate: Date?

    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController!
    private var updater: SPUUpdater { updaterController.updater }
    #endif

    private let updateFeedURL = "https://echotune.app/appcast.xml"
    private let checkInterval: TimeInterval = 86400 // 24 hours

    private init() {
        loadSettings()
        setupSparkle()
        debugLog("📦 UpdateManager initialized")
    }

    private func setupSparkle() {
        #if canImport(Sparkle)
        // Initialize Sparkle updater controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Configure update settings
        updater.automaticallyChecksForUpdates = automaticUpdatesEnabled
        updater.updateCheckInterval = checkInterval

        debugLog("✅ Sparkle updater initialized")
        debugLog("   Feed URL: \(updater.feedURL?.absoluteString ?? updateFeedURL)")
        debugLog("   Auto-check: \(updater.automaticallyChecksForUpdates)")
        #else
        debugLog("⚠️ Sparkle not available - using manual update check")
        #endif
    }

    // MARK: - Public API

    /// Check for updates manually (shows UI)
    func checkForUpdates() {
        debugLog("🔍 Checking for updates...")
        isCheckingForUpdates = true

        #if canImport(Sparkle)
        updaterController.checkForUpdates(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isCheckingForUpdates = false
            self.lastCheckDate = Date()
            self.saveSettings()
        }
        #else
        // Fallback: Check appcast manually
        Task {
            await checkForUpdatesManually()
        }
        #endif
    }

    /// Check for updates in background (silent)
    func checkForUpdatesInBackground() {
        guard automaticUpdatesEnabled else { return }

        debugLog("🔍 Checking for updates in background...")

        #if canImport(Sparkle)
        updater.checkForUpdatesInBackground()
        #else
        Task {
            await checkForUpdatesManually(silent: true)
        }
        #endif
    }

    /// Manual update check (when Sparkle is not available)
    private func checkForUpdatesManually(silent: Bool = false) async {
        do {
            let updateInfo = try await fetchUpdateInfo()

            await MainActor.run {
                isCheckingForUpdates = false
                lastCheckDate = Date()
                saveSettings()

                if let info = updateInfo {
                    let currentVersion = getCurrentVersionNumber()
                    if info.version.compare(currentVersion, options: .numeric) == .orderedDescending {
                        updateAvailable = true
                        latestVersion = info.version
                        releaseNotes = info.releaseNotes

                        if !silent {
                            showUpdateAvailableAlert(info: info)
                        }
                    } else if !silent {
                        showNoUpdateAlert()
                    }
                } else if !silent {
                    showNoUpdateAlert()
                }
            }
        } catch {
            await MainActor.run {
                isCheckingForUpdates = false
                if !silent {
                    showUpdateErrorAlert(error: error)
                }
            }
        }
    }

    /// Enable/disable automatic updates
    func setAutomaticUpdates(enabled: Bool) {
        automaticUpdatesEnabled = enabled
        saveSettings()

        #if canImport(Sparkle)
        updater.automaticallyChecksForUpdates = enabled
        #endif

        debugLog("⚙️ Automatic updates \(enabled ? "enabled" : "disabled")")
    }

    /// Get current app version string
    func getCurrentVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "Unknown"
    }

    /// Get current app version number only
    func getCurrentVersionNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Get update feed URL
    func getUpdateFeedURL() -> String {
        #if canImport(Sparkle)
        return updater.feedURL?.absoluteString ?? updateFeedURL
        #else
        return updateFeedURL
        #endif
    }

    // MARK: - Update Information

    struct UpdateInfo: Codable {
        let version: String
        let releaseDate: Date?
        let releaseNotes: String
        let downloadURL: String
        let fileSize: Int64?
        let minimumSystemVersion: String?
    }

    /// Fetch update information from appcast feed
    func fetchUpdateInfo() async throws -> UpdateInfo? {
        guard let url = URL(string: updateFeedURL) else {
            throw UpdateError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        // Parse appcast XML
        let parser = AppcastParser()
        let items = parser.parse(data: data)

        // Return latest item
        return items.first
    }

    // MARK: - UI Alerts

    private func showUpdateAvailableAlert(info: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "EchoTune \(info.version) is available. You're running \(getCurrentVersion()).\n\n\(info.releaseNotes)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: info.downloadURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "EchoTune \(getCurrentVersion()) is currently the newest version available."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showUpdateErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Could not check for updates: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        UserDefaults.standard.set(automaticUpdatesEnabled, forKey: "automaticUpdatesEnabled")
        if let lastCheck = lastCheckDate {
            UserDefaults.standard.set(lastCheck, forKey: "lastUpdateCheck")
        }
    }

    private func loadSettings() {
        automaticUpdatesEnabled = UserDefaults.standard.bool(forKey: "automaticUpdatesEnabled")
        lastCheckDate = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date

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
        case parseError

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
            case .parseError:
                return "Failed to parse update feed"
            }
        }
    }
}

// MARK: - Appcast Parser

/// Simple XML parser for Sparkle appcast feeds
private class AppcastParser: NSObject, XMLParserDelegate {
    private var items: [UpdateManager.UpdateInfo] = []
    private var currentElement = ""
    private var currentVersion = ""
    private var currentReleaseNotes = ""
    private var currentDownloadURL = ""
    private var currentMinimumSystemVersion = ""
    private var currentFileSize: Int64 = 0
    private var isInItem = false

    func parse(data: Data) -> [UpdateManager.UpdateInfo] {
        items = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isInItem = true
            currentVersion = ""
            currentReleaseNotes = ""
            currentDownloadURL = ""
            currentMinimumSystemVersion = ""
            currentFileSize = 0
        } else if elementName == "enclosure" && isInItem {
            if let url = attributeDict["url"] {
                currentDownloadURL = url
            }
            if let version = attributeDict["sparkle:version"] {
                currentVersion = version
            }
            if let length = attributeDict["length"], let size = Int64(length) {
                currentFileSize = size
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && isInItem else { return }

        switch currentElement {
        case "sparkle:version":
            currentVersion += trimmed
        case "sparkle:releaseNotesLink":
            currentReleaseNotes += trimmed
        case "sparkle:minimumSystemVersion":
            currentMinimumSystemVersion += trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" && isInItem {
            let info = UpdateManager.UpdateInfo(
                version: currentVersion,
                releaseDate: nil,
                releaseNotes: currentReleaseNotes,
                downloadURL: currentDownloadURL,
                fileSize: currentFileSize > 0 ? currentFileSize : nil,
                minimumSystemVersion: currentMinimumSystemVersion.isEmpty ? nil : currentMinimumSystemVersion
            )
            items.append(info)
            isInItem = false
        }
        currentElement = ""
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
