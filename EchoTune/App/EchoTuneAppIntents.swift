//
//  EchoTuneAppIntents.swift
//  EchoTune
//
//  ET-769 · Apple Shortcuts & Siri integration.
//
//  WHY THIS EXISTS
//  ---------------
//  Dictation should be a system-level verb, not a thing you have to find a menu
//  for. With App Intents, "Hey Siri, dictate in EchoTune" works, and Shortcuts can
//  chain dictation into anything else on the Mac.
//
//  Every intent declares `openAppWhenRun = false`, so triggering dictation never
//  brings a window forward — EchoTune is a menu bar app and should stay out of the
//  way.
//

import AppIntents
import AppKit
import Foundation

// MARK: - Toggle

struct ToggleDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Dictation"
    static var description = IntentDescription(
        "Start dictating if EchoTune is idle, or finish if it is recording."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = AppCoordinator.shared
        coordinator.toggleDictation()
        return .result(dialog: IntentDialog(stringLiteral: "Toggled EchoTune dictation."))
    }
}

// MARK: - Start

struct StartDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Dictation"
    static var description = IntentDescription(
        "Begin listening with EchoTune without showing a window."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = AppCoordinator.shared
        coordinator.startDictation()
        return .result(dialog: IntentDialog(stringLiteral: "EchoTune is listening."))
    }
}

// MARK: - Stop

struct StopDictationIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Dictation"
    static var description = IntentDescription(
        "Finish the current EchoTune recording and insert the transcription."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinator = AppCoordinator.shared
        coordinator.stopDictation()
        return .result(dialog: IntentDialog(stringLiteral: "Stopped EchoTune dictation."))
    }
}

// MARK: - Copy last transcript

struct CopyLastTranscriptIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Last Transcript"
    static var description = IntentDescription(
        "Copy your most recent EchoTune transcription to the clipboard."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = EchoTuneIntentSupport.lastTranscriptText() ?? ""
        guard !text.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: "There is no transcript to copy yet."))
        }
        EchoTuneIntentSupport.copyToClipboard(text)
        return .result(dialog: IntentDialog(stringLiteral: "Copied your last transcript."))
    }
}

// MARK: - Shortcuts phrases

/// Groups the intents so Shortcuts files them under "EchoTune" and Siri can offer
/// them by name.
struct EchoTuneShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: [
                "Toggle dictation in \(.applicationName)",
                "Toggle \(.applicationName) dictation"
            ],
            shortTitle: "Toggle Dictation",
            systemImageName: "mic"
        )
        AppShortcut(
            intent: StartDictationIntent(),
            phrases: [
                "Start dictating in \(.applicationName)",
                "Start \(.applicationName) dictation"
            ],
            shortTitle: "Start Dictation",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopDictationIntent(),
            phrases: [
                "Stop dictating in \(.applicationName)",
                "Stop \(.applicationName) dictation"
            ],
            shortTitle: "Stop Dictation",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: CopyLastTranscriptIntent(),
            phrases: [
                "Copy my last \(.applicationName) transcript"
            ],
            shortTitle: "Copy Last Transcript",
            systemImageName: "doc.on.doc"
        )
    }
}

// MARK: - Shared helpers

/// Thin seam between the intents and app state, so the intent bodies stay
/// testable without standing up a real coordinator.
enum EchoTuneIntentSupport {

    /// Most recent transcript text, or nil when the history is empty.
    @MainActor
    static func lastTranscriptText() -> String? {
        let items = TranscriptionHistoryManager.shared.transcriptions
        guard let latest = items.max(by: { $0.date < $1.date }) else { return nil }
        let text = latest.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    @MainActor
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}