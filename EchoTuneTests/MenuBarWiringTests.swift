import AppKit
import Foundation
import Testing
@testable import EchoTune

/// Menu-bar action wiring.
///
/// Every menu item in the status bar resolves to an `@objc` method on
/// `StatusBarController`. A selector that no longer exists — or a handler that
/// calls a `nil` optional — makes the item silently do nothing, which is exactly
/// the failure mode that is hardest to notice. These tests pin both.
struct MenuBarWiringTests {

    private func statusBarSource() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Views/MenuBar/StatusBarController.swift")
        return try String(contentsOf: root, encoding: .utf8)
    }

    /// Every `#selector(...)` referenced when building the menu.
    private func referencedSelectors(in source: String) -> [String] {
        var found: Set<String> = []
        var remainder = Substring(source)
        while let range = remainder.range(of: "#selector(") {
            remainder = remainder[range.upperBound...]
            guard let close = remainder.firstIndex(of: ")") else { break }
            let body = remainder[remainder.startIndex..<close]
            // `#selector(method)` or `#selector(method(_:))`
            let name = body.split(separator: "(").first.map(String.init) ?? String(body)
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { found.insert(trimmed) }
            remainder = remainder[close...].dropFirst()
        }
        return found.sorted()
    }

    /// Every `@objc` method the controller actually implements.
    private func implementedMethods(in source: String) -> Set<String> {
        var found: Set<String> = []
        for line in source.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("@objc"), trimmed.contains("func ") else { continue }
            guard let funcRange = trimmed.range(of: "func ") else { continue }
            let after = trimmed[funcRange.upperBound...]
            let name = after.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if !name.isEmpty { found.insert(String(name)) }
        }
        return found
    }

    // MARK: Acceptance criteria

    @Test func everyMenuSelectorHasAnImplementation() throws {
        let source = try statusBarSource()
        let referenced = referencedSelectors(in: source)
        let implemented = implementedMethods(in: source)

        #expect(referenced.count > 15, "expected to find the menu's selectors, found \(referenced.count)")

        let dangling = referenced.filter { !implemented.contains($0) }
        #expect(dangling.isEmpty, "these menu items point at missing handlers and do nothing when clicked: \(dangling)")
    }

    @Test func settingsOpenersMapToRealTabs() throws {
        let source = try statusBarSource()
        // Every `showSettings(tab: .x)` must name a case that exists.
        var remainder = Substring(source)
        var tabs: [String] = []
        while let range = remainder.range(of: "showSettings(tab: .") {
            remainder = remainder[range.upperBound...]
            let name = remainder.prefix { $0.isLetter || $0.isNumber }
            if !name.isEmpty { tabs.append(String(name)) }
        }
        #expect(!tabs.isEmpty)

        let valid = Set(SettingsTab.allCases.map { $0.rawValue })
        let validCaseNames = Set(SettingsTab.allCases.map { settingsTabCaseName($0) })
        for tab in tabs {
            #expect(validCaseNames.contains(tab), "'\(tab)' is not a SettingsTab case; valid: \(valid)")
        }
    }

    private func settingsTabCaseName(_ tab: SettingsTab) -> String {
        // Mirror the enum's case identifiers.
        switch tab {
        case .general: return "general"
        case .speech: return "speech"
        case .hotkeys: return "hotkeys"
        case .permissions: return "permissions"
        case .aiModels: return "aiModels"
        case .automation: return "automation"
        case .performance: return "performance"
        case .privacy: return "privacy"
        case .license: return "license"
        }
    }

    @Test func navigateSettingsNotificationIsPosted() throws {
        let source = try statusBarSource()
            + (try String(contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("EchoTune/App/AppDelegate.swift"), encoding: .utf8))
        #expect(source.contains("NavigateSettingsToTab"))
    }

    // MARK: The reported bug

    @Test func settingsOpensOnTheRequestedTabWithoutDependingOnAnExistingWindow() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("EchoTune/App/AppDelegate.swift"),
            encoding: .utf8
        )

        // The window must be constructed already knowing its tab...
        #expect(appDelegate.contains("SettingsView(initialTab:"),
                "a fresh Settings window must be built on the requested tab")
        // ...and raised before the tab is switched.
        let focusIndex = try #require(appDelegate.range(of: "focusForMenuBarPresentation(settingsWindow)")?.lowerBound)
        let postIndex = try #require(appDelegate.range(of: "NavigateSettingsToTab\"")?.lowerBound)
        #expect(focusIndex < postIndex, "the window must be raised before the tab notification is posted")
    }

    @Test func menuBarWindowsUseTheSharedFocusPath() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("EchoTune/App/AppDelegate.swift"),
            encoding: .utf8
        )
        // Dashboard, Settings, Echo Profile and Tasks must all be reachable from
        // an .accessory app, which needs activate() before raising the window.
        #expect(appDelegate.contains("func focusForMenuBarPresentation"))
        #expect(appDelegate.components(separatedBy: "focusForMenuBarPresentation(").count - 1 >= 3)
    }
}
