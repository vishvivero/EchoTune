import AppKit
import Foundation
import Testing
@testable import EchoTune

/// Clipboard-focused Recent tab.
@MainActor
struct ClipboardHistoryManagerTests {

    /// A private pasteboard so tests never touch the user's real clipboard.
    private func makeManager() -> (ClipboardHistoryManager, NSPasteboard) {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("echotune-test-\(UUID().uuidString)"))
        let manager = ClipboardHistoryManager(pasteboard: pasteboard)
        manager.clear()
        return (manager, pasteboard)
    }

    @Test func recordingADictationCopyAddsAnEntry() {
        let (manager, _) = makeManager()
        manager.recordDictationCopy("hello from dictation")
        #expect(manager.entries.count == 1)
        #expect(manager.entries.first?.text == "hello from dictation")
        #expect(manager.entries.first?.source == .dictation)
    }

    @Test func repeatedValuesMoveToTheTopInsteadOfDuplicating() {
        let (manager, _) = makeManager()
        manager.recordDictationCopy("first")
        manager.recordDictationCopy("second")
        manager.recordDictationCopy("first")

        #expect(manager.entries.count == 2, "a repeat must not duplicate")
        #expect(manager.entries.first?.text == "first", "it must move to the top")
    }

    @Test func whitespaceAndEmptyValuesAreIgnored() {
        let (manager, _) = makeManager()
        manager.recordDictationCopy("")
        manager.recordDictationCopy("   \n  ")
        #expect(manager.entries.isEmpty)
    }

    @Test func oversizedBlobsAreIgnored() {
        let (manager, _) = makeManager()
        manager.recordDictationCopy(String(repeating: "a", count: 20_001))
        #expect(manager.entries.isEmpty, "huge values are not transcripts")
    }

    @Test func historyIsCappedAtCapacity() {
        let (manager, _) = makeManager()
        for index in 0..<(ClipboardHistoryManager.capacity + 10) {
            manager.recordDictationCopy("clip \(index)")
        }
        #expect(manager.entries.count == ClipboardHistoryManager.capacity)
        // Newest first: the last recorded value must be at the top.
        #expect(manager.entries.first?.text == "clip \(ClipboardHistoryManager.capacity + 9)")
    }

    // MARK: Search

    @Test func searchIsCaseAndDiacriticInsensitive() {
        let (manager, _) = makeManager()
        manager.recordDictationCopy("Deploy to Kubernetes")
        manager.recordDictationCopy("Buy milk and café beans")
        manager.recordDictationCopy("Reply to Vish's email")

        #expect(manager.search("kubernetes").count == 1)
        #expect(manager.search("KUBERNETES").count == 1)
        #expect(manager.search("cafe").count == 1, "diacritics must not block a match")
        #expect(manager.search("email").count == 1)
        #expect(manager.search("zzz").isEmpty)
    }

    @Test func emptySearchReturnsEverything() {
        let (manager, _) = makeManager()
        manager.recordDictationCopy("one")
        manager.recordDictationCopy("two")
        #expect(manager.search("").count == 2)
        #expect(manager.search("   ").count == 2)
    }

    @Test func searchAvoidsRegexInterpretation() {
        let (manager, _) = makeManager()
        manager.recordDictationCopy("cost is $5 (approx)")
        // A query full of regex metacharacters must be treated literally.
        #expect(manager.search("$5 (").count == 1)
        #expect(manager.search(".*").isEmpty)
    }

    // MARK: Privacy

    @Test func passwordManagersAreExcluded() {
        for id in ["com.1password.1password", "com.bitwarden.desktop", "com.apple.Passwords"] {
            #expect(ClipboardHistoryManager.excludedBundleIdentifiers.contains(id),
                    "\(id) must never be recorded")
        }
        #expect(ClipboardHistoryManager.excludedBundleIdentifiers.contains("com.apple.Safari") == false)
    }

    @Test func clipboardHistoryIsNotPersistedToDisk() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Managers/ClipboardHistoryManager.swift")
        let source = try String(contentsOf: root, encoding: .utf8)
        #expect(!source.contains("UserDefaults"), "clipboard history must stay in memory only")
        #expect(!source.contains("FileManager"), "clipboard history must never be written to disk")
    }
}

/// The native menu tail adapts to the selected card tab.
struct MenuBarTabAdaptivityTests {

    private func controllerSource() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Views/MenuBar/StatusBarController.swift")
        return try String(contentsOf: root, encoding: .utf8)
    }

    @Test func nativeTailIsTabAware() throws {
        let source = try controllerSource()
        #expect(source.contains("switch activeCardTab"))
        #expect(source.contains("case .overview:"))
        #expect(source.contains("case .controls:"))
        #expect(source.contains("case .recent:"))
    }

    @Test func controlsTabAddsNothingAfterTheCard() throws {
        let source = try controllerSource()
        // The .controls branch must be a no-op: the card already ends at the
        // dictation sound cue toggles.
        let controlsBranch = try #require(source.range(of: "case .controls:"))
        let recentBranch = try #require(source.range(of: "case .recent:"))
        let body = source[controlsBranch.upperBound..<recentBranch.lowerBound]
        #expect(!body.contains("rootMenu.addItem"),
                "the Controls tab must not append pipeline or workspace items")
    }

    @Test func overviewStillAddsEverySection() throws {
        let source = try controllerSource()
        let overview = try #require(source.range(of: "case .overview:"))
        let controls = try #require(source.range(of: "case .controls:"))
        let body = source[overview.upperBound..<controls.lowerBound]
        #expect(body.contains("addWorkspaceSection()"))
        #expect(body.contains("addSettingsSection()"))
        #expect(body.contains("makeModelSubmenuItem()"))
        #expect(body.contains("makeRecentDictationsSubmenuItem()"))
    }

    @Test func tabChangeTriggersARebuild() throws {
        let source = try controllerSource()
        #expect(source.contains("presentation.onTabChanged"))
        #expect(source.contains("rebuildDynamicMenuItems()"))
    }
}
