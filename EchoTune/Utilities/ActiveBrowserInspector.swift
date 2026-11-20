//
//  ActiveBrowserInspector.swift
//  EchoTune
//
//  Answers two questions about the frontmost application: is it a web
//  browser, and if so, which URL is showing in its active tab. Used by
//  Power Modes to pick per-site configurations.
//

import AppKit
import ApplicationServices

enum ActiveBrowserInspector {

    private enum TabQuery {
        case chromium(scriptName: String)
        case webKit(scriptName: String)
        case accessibilityAddressBar
    }

    private static let knownBrowsers: [String: TabQuery] = [
        "com.apple.Safari": .webKit(scriptName: "Safari"),
        "com.kagi.kagimacOS": .webKit(scriptName: "Orion"),
        "com.google.Chrome": .chromium(scriptName: "Google Chrome"),
        "com.brave.Browser": .chromium(scriptName: "Brave Browser"),
        "com.microsoft.edgemac": .chromium(scriptName: "Microsoft Edge"),
        "company.thebrowser.Browser": .chromium(scriptName: "Arc"),
        "company.thebrowser.dia": .chromium(scriptName: "Dia"),
        "ai.perplexity.comet": .chromium(scriptName: "Comet"),
        "com.operasoftware.Opera": .chromium(scriptName: "Opera"),
        "com.vivaldi.Vivaldi": .chromium(scriptName: "Vivaldi"),
        "ru.yandex.desktop.yandex-browser": .chromium(scriptName: "Yandex"),
        "org.mozilla.firefox": .accessibilityAddressBar,
        "org.mozilla.firefoxdeveloperedition": .accessibilityAddressBar,
        "app.zen-browser.zen": .accessibilityAddressBar,
        "io.github.zen-browser.app": .accessibilityAddressBar,
    ]

    static func isBrowser(_ bundleIdentifier: String) -> Bool {
        knownBrowsers[bundleIdentifier] != nil
    }

    static func frontmostTabURL() -> URL? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              let query = knownBrowsers[bundleID] else {
            return nil
        }

        switch query {
        case .chromium(let name):
            return runTabAppleScript("tell application \"\(name)\" to return URL of active tab of front window")
        case .webKit(let name):
            return runTabAppleScript("tell application \"\(name)\" to return URL of front document")
        case .accessibilityAddressBar:
            return readURLViaAccessibility(pid: frontApp.processIdentifier)
        }
    }

    private static func runTabAppleScript(_ source: String) -> URL? {
        var scriptError: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&scriptError)
        if scriptError != nil { return nil }
        guard let urlString = output.stringValue, !urlString.isEmpty else { return nil }
        return normalizedURL(from: urlString)
    }

    /// Best-effort AX URL bar reader for Gecko browsers (Firefox, Zen) that lack AppleScript dictionaries.
    private static func readURLViaAccessibility(pid: pid_t) -> URL? {
        guard AXIsProcessTrusted() else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let win = windowRef,
              CFGetTypeID(win) == AXUIElementGetTypeID() else {
            return nil
        }
        let windowElement = unsafeBitCast(win, to: AXUIElement.self)

        // Check AXDocument attribute first (exposed by several Gecko builds)
        var docRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(windowElement, kAXDocumentAttribute as CFString, &docRef) == .success,
           let docStr = docRef as? String,
           let url = normalizedURL(from: docStr) {
            return url
        }

        // Shallow BFS (max 60 nodes) looking for a toolbar text field holding a domain/URL
        var queue: [AXUIElement] = [windowElement]
        var visited = 0
        while !queue.isEmpty && visited < 60 {
            let current = queue.removeFirst()
            visited += 1

            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String,
               (role == kAXTextFieldRole as String || role == "AXComboBox") {
                var valRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valRef) == .success,
                   let val = valRef as? String,
                   let url = normalizedURL(from: val) {
                    return url
                }
            }

            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                queue.append(contentsOf: children.prefix(12))
            }
        }
        return nil
    }

    static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.contains(".") && !trimmed.hasPrefix("about:") {
            return URL(string: "https://\(trimmed)")
        }
        return nil
    }
}
