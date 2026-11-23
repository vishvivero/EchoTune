import AppKit
import Foundation
import Testing
@testable import EchoTune

/// ET-769 · Apple Shortcuts & Siri integration.
struct EchoTuneAppIntentsTests {

    // MARK: Acceptance criteria

    @Test func everyIntentRunsWithoutOpeningAWindow() {
        // The whole point: dictation is a background verb. A window coming forward
        // would steal focus mid-sentence in whatever app you are typing into.
        #expect(ToggleDictationIntent.openAppWhenRun == false)
        #expect(StartDictationIntent.openAppWhenRun == false)
        #expect(StopDictationIntent.openAppWhenRun == false)
        #expect(CopyLastTranscriptIntent.openAppWhenRun == false)
    }

    @Test func everyIntentIsTitledAndDescribed() {
        #expect(!String(localized: ToggleDictationIntent.title).isEmpty)
        #expect(!String(localized: StartDictationIntent.title).isEmpty)
        #expect(!String(localized: StopDictationIntent.title).isEmpty)
        #expect(!String(localized: CopyLastTranscriptIntent.title).isEmpty)

        // IntentDescription's text is not introspectable; assert the non-empty
        // titles above and the wiring below instead.
    }

    @Test func shortcutsAreRegisteredUnderTheAppName() {
        // AppShortcut exposes no public accessors, so assert the provider builds
        // without trapping and declares the four intents.
        let shortcuts = EchoTuneShortcuts.appShortcuts
        #expect(shortcuts.count == 4, "toggle, start, stop and copy")
    }

    // MARK: Support helpers

    @MainActor
    @Test func lastTranscriptTextIsTrimmedAndNilWhenEmpty() {
        let manager = TranscriptionHistoryManager.shared
        let original = manager.transcriptions
        defer { manager.transcriptions = original }

        manager.transcriptions = []
        #expect(EchoTuneIntentSupport.lastTranscriptText() == nil)

        manager.transcriptions = [
            TranscriptionHistoryItem(
                date: Date(timeIntervalSince1970: 1_000),
                text: "  older  ",
                duration: 1,
                originalText: "older",
                rawTranscriptionText: "older"
            ),
            TranscriptionHistoryItem(
                date: Date(timeIntervalSince1970: 2_000),
                text: "   ",
                duration: 1,
                originalText: "blank",
                rawTranscriptionText: "blank"
            )
        ]
        // The newest entry is whitespace-only, so there is nothing to copy.
        #expect(EchoTuneIntentSupport.lastTranscriptText() == nil)
    }

    @MainActor
    @Test func lastTranscriptPicksTheNewestEntry() {
        let manager = TranscriptionHistoryManager.shared
        let original = manager.transcriptions
        defer { manager.transcriptions = original }

        manager.transcriptions = [
            TranscriptionHistoryItem(
                date: Date(timeIntervalSince1970: 1_000),
                text: "older text",
                duration: 1,
                originalText: "older text",
                rawTranscriptionText: "older text"
            ),
            TranscriptionHistoryItem(
                date: Date(timeIntervalSince1970: 2_000),
                text: "  newest text  ",
                duration: 1,
                originalText: "newest text",
                rawTranscriptionText: "newest text"
            )
        ]
        #expect(EchoTuneIntentSupport.lastTranscriptText() == "newest text")
    }

    @MainActor
    @Test func copyToClipboardWritesTheString() {
        EchoTuneIntentSupport.copyToClipboard("copied by intent")
        #expect(NSPasteboard.general.string(forType: .string) == "copied by intent")
    }

    // MARK: Wiring

    @Test func intentsCallTheCoordinatorEntryPoints() throws {
        var root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        root.appendPathComponent("EchoTune/App/EchoTuneAppIntents.swift")
        let source = try String(contentsOf: root, encoding: .utf8)

        #expect(source.contains("coordinator.toggleDictation()"))
        #expect(source.contains("coordinator.startDictation()"))
        #expect(source.contains("coordinator.stopDictation()"))
    }
}
