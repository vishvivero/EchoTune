//
//  ActiveBrowserInspector.swift
//  EchoTune
//
//  Answers two questions about the frontmost application: is it a web
//  browser, and if so, which URL is showing in its active tab. Used by
//  Power Modes to pick per-site configurations.
//

import AppKit

enum ActiveBrowserInspector {

    /// How to ask a given browser for its current tab URL over AppleScript.
    private enum TabQuery {
        /// Chromium lineage: `active tab of front window`.
        case chromium(scriptName: String)
        /// WebKit lineage (Safari and friends): `front document`.
        case webKit(scriptName: String)
        /// Browser exposes no scripting interface for tabs.
        case unsupported
    }

    /// Bundle identifiers are plain platform facts; the mapping decides which
    /// scripting dialect (if any) each browser speaks.
    private static let knownBrowsers: [String: TabQuery] = [
        "com.apple.Safari": .webKit(scriptName: "Safari"),
        "com.kagi.kagimacOS": .webKit(scriptName: "Orion"),
        "com.google.Chrome": .chromium(scriptName: "Google Chrome"),
        "com.brave.Browser": .chromium(scriptName: "Brave Browser"),
        "com.microsoft.edgemac": .chromium(scriptName: "Microsoft Edge"),
        "company.thebrowser.Browser": .chromium(scriptName: "Arc"),
        "com.operasoftware.Opera": .chromium(scriptName: "Opera"),
        "com.vivaldi.Vivaldi": .chromium(scriptName: "Vivaldi"),
        "ru.yandex.desktop.yandex-browser": .chromium(scriptName: "Yandex"),
        "org.mozilla.firefox": .unsupported,
        "io.github.zen-browser.app": .unsupported,
    ]

    /// Whether the given bundle identifier belongs to a known web browser.
    static func isBrowser(_ bundleIdentifier: String) -> Bool {
        knownBrowsers[bundleIdentifier] != nil
    }

    /// The URL of the active tab in the frontmost app, when that app is a
    /// scriptable browser. Returns nil for non-browsers, unscriptable
    /// browsers, or when the user has denied Apple Events permission.
    static func frontmostTabURL() -> URL? {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              let query = knownBrowsers[bundleID] else {
            return nil
        }

        let source: String
        switch query {
        case .chromium(let name):
            source = "tell application \"\(name)\" to return URL of active tab of front window"
        case .webKit(let name):
            source = "tell application \"\(name)\" to return URL of front document"
        case .unsupported:
            return nil
        }

        var scriptError: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&scriptError)

        if let scriptError {
            debugLog("🌐 Tab URL query failed: \(scriptError)")
            return nil
        }

        guard let urlString = output.stringValue, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
}
