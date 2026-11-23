import AppKit
import Foundation
import Testing
@testable import EchoTune

/// Menu card layout + clipboard list completeness.
@MainActor
struct MenuCardLayoutTests {

    private func cardSource() throws -> String {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Views/MenuBar/EchoTuneMenuCardView.swift")
        return try String(contentsOf: root, encoding: .utf8)
    }

    private func code(_ source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: Top alignment

    @Test func cardIsPinnedToTheTopLeft() throws {
        let source = code(try cardSource())
        // `.leading` centres vertically inside a taller slot, which is what made
        // the whole card drift as tabs changed height.
        #expect(source.contains("alignment: .topLeading"),
                "the card root must use topLeading, not leading")
        #expect(!source.contains(".frame(width: EchoMenuCardLayout.width, alignment: .leading)"),
                "a leading-aligned root frame re-introduces vertical centring")
    }

    @Test func innerColumnHugsTheTop() throws {
        let source = code(try cardSource())
        #expect(source.contains(".frame(maxWidth: .infinity, alignment: .topLeading)"))
    }

    @Test func hostingViewIsAnchoredToTheTopOfItsSlot() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/Views/MenuBar/StatusBarController.swift")
        let source = try String(contentsOf: root, encoding: .utf8)
        #expect(source.contains("autoresizingMask = [.minYMargin]"),
                "AppKit centres an unmeasurable custom menu view unless it is top-anchored")
    }

    // MARK: Recent list completeness

    @Test func recentTabShowsEveryMatchingClip() throws {
        let source = code(try cardSource())
        #expect(source.contains("ForEach(results)"),
                "the Recent list must render every match, not a truncated prefix")
        #expect(!source.contains("results.prefix("),
                "prefix() silently hid clips the search had matched")
    }

    @Test func storeCapacityIsTheOnlyLimitAndIsLargeEnough() {
        #expect(ClipboardHistoryManager.capacity >= 50,
                "a session's clips must not be dropped; capacity is \(ClipboardHistoryManager.capacity)")
    }

    @Test func storeKeepsEveryClipUpToCapacity() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("echotune-layout-\(UUID().uuidString)"))
        let manager = ClipboardHistoryManager(pasteboard: pasteboard)
        manager.clear()

        let count = 60
        for index in 0..<count {
            manager.recordDictationCopy("clip number \(index)")
        }
        #expect(manager.entries.count == count, "all \(count) clips must be retained")
        #expect(manager.search("clip").count == count, "search must surface all of them")
    }

    @Test func searchDoesNotTruncateResults() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("echotune-search-\(UUID().uuidString)"))
        let manager = ClipboardHistoryManager(pasteboard: pasteboard)
        manager.clear()

        for index in 0..<40 {
            manager.recordDictationCopy("deployment note \(index)")
        }
        #expect(manager.search("deployment").count == 40)
    }
}
