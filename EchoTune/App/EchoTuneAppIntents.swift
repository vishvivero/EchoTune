//
//  EchoTuneAppIntents.swift
//  EchoTune
//
//  Native macOS AppIntents for Apple Shortcuts, Siri, Raycast, Stream Deck,
//  and Automation workflows.
//

import AppIntents
import AppKit
import Foundation

struct ToggleDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle EchoTune Dictation"
    static let description = IntentDescription("Starts or stops voice dictation in EchoTune.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        AppCoordinator.shared.toggleDictation()
        return .result()
    }
}

struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Start EchoTune Dictation"
    static let description = IntentDescription("Starts recording voice dictation if EchoTune is idle.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        if AppState.shared.recordingState == .idle {
            AppCoordinator.shared.startDictation()
        }
        return .result()
    }
}

struct StopDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop EchoTune Dictation"
    static let description = IntentDescription("Stops an active EchoTune dictation and transcribes it.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        if AppState.shared.recordingState == .recording {
            AppCoordinator.shared.toggleDictation()
        }
        return .result()
    }
}

struct CopyLastTranscriptIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Last EchoTune Transcript"
    static let description = IntentDescription("Copies your most recent EchoTune transcription to the clipboard and returns it.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let text = TranscriptionHistoryManager.shared.transcriptions.first?.text ?? ""
        if !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        return .result(value: text)
    }
}

struct OpenQuickHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open EchoTune Quick History"
    static let description = IntentDescription("Opens EchoTune's floating Quick History search panel.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickHistoryPanelController.shared.toggle()
        return .result()
    }
}

struct EchoTuneShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: [
                "Toggle dictation in \(.applicationName)",
                "Dictate with \(.applicationName)"
            ],
            shortTitle: "Toggle Dictation",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: CopyLastTranscriptIntent(),
            phrases: [
                "Copy last dictation from \(.applicationName)"
            ],
            shortTitle: "Copy Last Transcript",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: OpenQuickHistoryIntent(),
            phrases: [
                "Search \(.applicationName) history"
            ],
            shortTitle: "Quick History",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
