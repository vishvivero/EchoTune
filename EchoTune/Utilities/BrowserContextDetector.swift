//
//  BrowserContextDetector.swift
//  EchoTune
//
//  Phase 3: Browser Context Detection via AppleScript
//  Detects active browser and current page context for smarter transcription
//

import Foundation
import AppKit

/// Detects browser context (URL, title) from supported browsers using AppleScript
class BrowserContextDetector {
    static let shared = BrowserContextDetector()

    enum SupportedBrowser: String, CaseIterable {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case firefox = "Firefox"
        case edge = "Microsoft Edge"
        case brave = "Brave Browser"
        case arc = "Arc"
        case opera = "Opera"
        case vivaldi = "Vivaldi"
        case yandex = "Yandex"
        case zen = "Zen Browser"
        case orion = "Orion"

        var bundleIdentifier: String {
            switch self {
            case .safari: return "com.apple.Safari"
            case .chrome: return "com.google.Chrome"
            case .firefox: return "org.mozilla.firefox"
            case .edge: return "com.microsoft.edgemac"
            case .brave: return "com.brave.Browser"
            case .arc: return "company.thebrowser.Browser"
            case .opera: return "com.operasoftware.Opera"
            case .vivaldi: return "com.vivaldi.Vivaldi"
            case .yandex: return "ru.yandex.desktop.yandex-browser"
            case .zen: return "io.github.zen-browser.app"
            case .orion: return "com.kagi.kagimacOS"
            }
        }
    }

    struct BrowserContext {
        let browser: SupportedBrowser
        let url: String?
        let title: String?
        let domain: String?

        var description: String {
            var parts: [String] = [browser.rawValue]
            if let domain = domain {
                parts.append("Domain: \(domain)")
            }
            if let title = title {
                parts.append("Page: \(title)")
            }
            return parts.joined(separator: " | ")
        }
    }

    private init() {}

    // MARK: - Public API

    /// Detects the current browser context (browser, URL, title)
    func detectContext() -> BrowserContext? {
        guard let activeBrowser = detectActiveBrowser() else {
            return nil
        }

        debugLog("🌐 Detected active browser: \(activeBrowser.rawValue)")

        let (url, title) = getBrowserInfo(for: activeBrowser)
        let domain = extractDomain(from: url)

        let context = BrowserContext(
            browser: activeBrowser,
            url: url,
            title: title,
            domain: domain
        )

        if url != nil || title != nil {
            debugLog("   URL: \(url ?? "unknown")")
            debugLog("   Title: \(title ?? "unknown")")
            debugLog("   Domain: \(domain ?? "unknown")")
        }

        return context
    }

    /// Check if a specific browser is currently active
    func isBrowserActive(_ browser: SupportedBrowser) -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        return activeApp.bundleIdentifier == browser.bundleIdentifier
    }

    /// Get list of currently running browsers
    func getRunningBrowsers() -> [SupportedBrowser] {
        let runningApps = NSWorkspace.shared.runningApplications
        return SupportedBrowser.allCases.filter { browser in
            runningApps.contains { $0.bundleIdentifier == browser.bundleIdentifier }
        }
    }

    // MARK: - Private Methods

    private func detectActiveBrowser() -> SupportedBrowser? {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = activeApp.bundleIdentifier else {
            return nil
        }

        return SupportedBrowser.allCases.first { browser in
            browser.bundleIdentifier == bundleId
        }
    }

    private func getBrowserInfo(for browser: SupportedBrowser) -> (url: String?, title: String?) {
        switch browser {
        case .safari, .orion:
            return getSafariInfo(browser: browser)
        case .chrome, .edge, .brave, .arc, .opera, .vivaldi, .yandex, .zen:
            return getChromeBasedInfo(browser: browser)
        case .firefox:
            return getFirefoxInfo()
        }
    }

    // MARK: - Safari-based Detection (Safari, Orion)

    private func getSafariInfo(browser: SupportedBrowser) -> (url: String?, title: String?) {
        let script = """
        tell application "\(browser.rawValue)"
            if (count of windows) > 0 then
                set currentTab to current tab of front window
                set pageURL to URL of currentTab
                set pageTitle to name of currentTab
                return pageURL & "|||" & pageTitle
            end if
        end tell
        """

        guard let result = executeAppleScript(script) else {
            return (nil, nil)
        }

        let parts = result.components(separatedBy: "|||")
        return (
            url: parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
            title: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
    }

    // MARK: - Chrome-based Browsers (Chrome, Edge, Brave, Arc, Opera, Vivaldi, Yandex, Zen)

    private func getChromeBasedInfo(browser: SupportedBrowser) -> (url: String?, title: String?) {
        let script = """
        tell application "\(browser.rawValue)"
            if (count of windows) > 0 then
                set currentTab to active tab of front window
                set pageURL to URL of currentTab
                set pageTitle to title of currentTab
                return pageURL & "|||" & pageTitle
            end if
        end tell
        """

        guard let result = executeAppleScript(script) else {
            return (nil, nil)
        }

        let parts = result.components(separatedBy: "|||")
        return (
            url: parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
            title: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
    }

    // MARK: - Firefox Detection

    private func getFirefoxInfo() -> (url: String?, title: String?) {
        // Firefox doesn't have native AppleScript support
        // We can try to get info from the window title which includes both
        guard let firefox = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == SupportedBrowser.firefox.bundleIdentifier
        }) else {
            return (nil, nil)
        }

        // Firefox window title format: "Page Title - Mozilla Firefox"
        // This is a fallback approach
        let script = """
        tell application "System Events"
            tell process "Firefox"
                if exists (1st window whose value of attribute "AXMain" is true) then
                    set windowTitle to value of attribute "AXTitle" of (1st window whose value of attribute "AXMain" is true)
                    return windowTitle
                end if
            end tell
        end tell
        """

        guard let windowTitle = executeAppleScript(script) else {
            return (nil, nil)
        }

        // Extract title (remove " - Mozilla Firefox" suffix)
        let title = windowTitle.replacingOccurrences(of: " - Mozilla Firefox", with: "")

        return (url: nil, title: title)
    }

    // MARK: - AppleScript Execution

    private func executeAppleScript(_ script: String) -> String? {
        var error: NSDictionary?

        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)

            if let error = error {
                // Silently fail - AppleScript errors are non-critical (usually permission issues)
                // URL/title context is optional, text insertion will still work
                if let errorNumber = error["NSAppleScriptErrorNumber"] as? Int,
                   errorNumber != -600 {  // -600 = "Application isn't running" (expected when Chrome closed)
                    debugLog("⚠️ AppleScript error: \(error)")
                }
                return nil
            }

            return output.stringValue
        }

        return nil
    }

    // MARK: - Domain Extraction

    private func extractDomain(from urlString: String?) -> String? {
        guard let urlString = urlString,
              let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }

        // Remove "www." prefix if present
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }

        return host
    }
}

// MARK: - Context Usage Examples

extension BrowserContextDetector {
    /// Returns a context hint for transcription based on the current page
    func getTranscriptionHint() -> String? {
        guard let context = detectContext() else {
            return nil
        }

        // Provide context hints based on domain
        if let domain = context.domain {
            switch domain {
            case _ where domain.contains("gmail.com"), _ where domain.contains("mail.google.com"):
                return "Email context detected"
            case _ where domain.contains("docs.google.com"):
                return "Google Docs context detected"
            case _ where domain.contains("notion.so"):
                return "Notion context detected"
            case _ where domain.contains("slack.com"):
                return "Slack context detected"
            case _ where domain.contains("github.com"):
                return "GitHub context detected - technical content likely"
            case _ where domain.contains("stackoverflow.com"):
                return "Stack Overflow context detected - technical content likely"
            default:
                return "Browsing: \(domain)"
            }
        }

        return nil
    }

    /// Check if transcription should use technical mode based on context
    func shouldUseTechnicalMode() -> Bool {
        guard let context = detectContext(),
              let domain = context.domain else {
            return false
        }

        let technicalDomains = [
            "github.com",
            "stackoverflow.com",
            "developer.apple.com",
            "docs.python.org",
            "golang.org",
            "rust-lang.org"
        ]

        return technicalDomains.contains { domain.contains($0) }
    }
}
