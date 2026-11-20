//
//  ConfigurationBackupManager.swift
//  EchoTune
//
//  Portable configuration backup (Export/Import JSON for Dictionary, Power Modes,
//  Trigger Rules, Filler Words, and Preferences — zero API/license keys included)
//  plus RFC-4180 CSV export for Transcription History (#15).
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ConfigurationBackupManager {
    struct BackupPayload: Codable {
        let formatVersion: Int
        let exportedAt: Date
        let appVersion: String
        let wordReplacements: [WordReplacement]
        let correctSpellings: [CorrectSpelling]
        let phoneticMatchingEnabled: Bool
        let fillerWords: [String]
        let fillerRemovalEnabled: Bool
        let powerModes: [PowerMode]
        let triggerWordRules: [TriggerWordRule]
        let customEnhancementPrompt: String
        let recordingMode: String
        let recorderStyle: String
        let pasteMethod: String
        let smartPunctuationEnabled: Bool
        let preferredLanguage: String
        let autoDetectLanguage: Bool
    }

    static func exportBackupData() throws -> Data {
        let settings = AppSettings.shared
        let dict = DictionaryManager.shared
        let fillers = FillerWordManager.shared

        let payload = BackupPayload(
            formatVersion: 1,
            exportedAt: Date(),
            appVersion: Bundle.main.appVersionString,
            wordReplacements: dict.wordReplacements,
            correctSpellings: dict.correctSpellings,
            phoneticMatchingEnabled: dict.phoneticMatchingEnabled,
            fillerWords: fillers.fillerWords,
            fillerRemovalEnabled: fillers.isEnabled,
            powerModes: PowerModeManager.shared.powerModes,
            triggerWordRules: AIEnhancementEngine.shared.triggerWordRules,
            customEnhancementPrompt: settings.customEnhancementPrompt,
            recordingMode: settings.recordingMode.rawValue,
            recorderStyle: settings.recorderStyle.rawValue,
            pasteMethod: settings.pasteMethod.rawValue,
            smartPunctuationEnabled: settings.smartPunctuationEnabled,
            preferredLanguage: settings.preferredLanguage,
            autoDetectLanguage: settings.autoDetectLanguage
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    @MainActor
    static func importBackupData(_ data: Data) throws -> String {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        let dict = DictionaryManager.shared
        var newReplacements = 0
        for r in payload.wordReplacements {
            if !dict.wordReplacements.contains(where: { $0.spokenForm.caseInsensitiveCompare(r.spokenForm) == .orderedSame }) {
                dict.addReplacement(r)
                newReplacements += 1
            }
        }

        var newSpellings = 0
        for s in payload.correctSpellings {
            if !dict.correctSpellings.contains(where: { $0.word.caseInsensitiveCompare(s.word) == .orderedSame }) {
                dict.addSpelling(s)
                newSpellings += 1
            }
        }
        dict.phoneticMatchingEnabled = payload.phoneticMatchingEnabled

        let fillers = FillerWordManager.shared
        fillers.fillerWords = payload.fillerWords
        fillers.isEnabled = payload.fillerRemovalEnabled

        let pm = PowerModeManager.shared
        var newModes = 0
        for mode in payload.powerModes {
            if !pm.powerModes.contains(where: { $0.name.caseInsensitiveCompare(mode.name) == .orderedSame }) {
                pm.addPowerMode(mode)
                newModes += 1
            }
        }

        let engine = AIEnhancementEngine.shared
        var newRules = 0
        for rule in payload.triggerWordRules {
            if !engine.triggerWordRules.contains(where: { $0.triggerPhrase.caseInsensitiveCompare(rule.triggerPhrase) == .orderedSame }) {
                engine.addTriggerWordRule(rule)
                newRules += 1
            }
        }

        let settings = AppSettings.shared
        if !payload.customEnhancementPrompt.isEmpty {
            settings.customEnhancementPrompt = payload.customEnhancementPrompt
        }
        if let mode = RecordingMode(rawValue: payload.recordingMode) {
            settings.recordingMode = mode
        }
        if let style = RecorderStyle(rawValue: payload.recorderStyle) {
            settings.recorderStyle = style
        }
        if let paste = PasteMethod(rawValue: payload.pasteMethod) {
            settings.pasteMethod = paste
        }
        settings.smartPunctuationEnabled = payload.smartPunctuationEnabled
        settings.preferredLanguage = payload.preferredLanguage
        settings.autoDetectLanguage = payload.autoDetectLanguage

        return "Imported \(newSpellings) spellings, \(newReplacements) replacements, \(newModes) modes, \(newRules) trigger rules."
    }

    // MARK: - RFC-4180 CSV Export for History

    static func buildHistoryCSV(items: [TranscriptionHistoryItem]) -> String {
        var rows: [String] = [
            "id,timestamp_iso8601,duration_seconds,word_count,language,provider,model,text,raw_text"
        ]
        let iso = ISO8601DateFormatter()

        for item in items {
            let words = item.text.split(whereSeparator: \.isWhitespace).count
            let cols: [String] = [
                csvEscape(item.id.uuidString),
                csvEscape(iso.string(from: item.date)),
                String(format: "%.2f", item.duration),
                String(words),
                csvEscape(item.detectedLanguage ?? ""),
                csvEscape(item.processingMetadata?.transcriptionProvider ?? ""),
                csvEscape(item.processingMetadata?.transcriptionModel ?? ""),
                csvEscape(item.text),
                csvEscape(item.rawTranscriptionText)
            ]
            rows.append(cols.joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return value
    }

    @MainActor
    static func presentHistoryCSVSavePanel() {
        let csv = buildHistoryCSV(items: TranscriptionHistoryManager.shared.transcriptions)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "EchoTune-History.csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? Data(csv.utf8).write(to: url, options: .atomic)
        }
    }
}
