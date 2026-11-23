//
//  ConfigurationBackupManager.swift
//  EchoTune
//
//  ET-764 · move your setup between Macs, and get your history out.
//
//  WHY THIS EXISTS
//  ---------------
//  A well-configured EchoTune (custom dictionary, power modes, trigger rules,
//  filler words, preferences) took real effort to build. Until now the only way
//  to move it to a second Mac was to rebuild it by hand.
//
//  Two exports, deliberately separated:
//
//    · Settings backup (JSON)   — configuration only. NEVER secrets.
//    · History export (CSV)     — transcripts, RFC 4180 compliant.
//
//  API keys and the licence key are stored in the Keychain and are *never*
//  written to a backup file. Re-enter them on the new machine.
//

import Foundation

final class ConfigurationBackupManager {

    static let shared = ConfigurationBackupManager()

    /// Bumped when the on-disk shape changes. Imports reject unknown majors
    /// rather than silently mis-reading them.
    static let currentSchemaVersion = 1

    private init() {}

    // MARK: - Backup model

    struct Backup: Codable {
        var schemaVersion: Int
        var appVersion: String
        var exportedAt: Date
        var dictionary: DictionaryManager.DictionaryExport
        var powerModes: [PowerMode]
        var triggerRules: [TriggerWordRule]
        var fillerWords: [String]
        /// Only the preference keys that are safe to move between machines.
        /// Keys are allow-listed, never dumped wholesale.
        var preferences: [String: String]
    }

    /// Preference keys that are backed up. Anything not listed here — notably
    /// API keys, the licence, and per-install identifiers — is intentionally
    /// excluded, because a backup file is not a secret store.
    static let allowedPreferenceKeys: [String] = [
        "recordingMode",
        "previewTier",
        "preferredLanguage",
        "autoDetectLanguage",
        "translateToEnglish",
        "vocabularyBiasingEnabled",
        "phoneticMatchingEnabled",
        "fillerRemovalEnabled",
        "keepAudioHistory",
        "smartCapitalization",
        "insertSpaceAfterText",
        "autoCorrection",
        "playSoundOnStartStop",
        "muteBackgroundAudio",
        "autoSendEnabled",
        "aiEnhancementEnabled",
        "selectedEnhancementModel",
        "customEnhancementPrompt",
        "stripEnhancementWrappers",
        "recorderStyle",
        "audioRetentionDays"
    ]

    /// Keys that must never appear in a backup, asserted in tests.
    static let forbiddenPreferenceKeys: [String] = [
        "groqAPIKey",
        "openaiAPIKey",
        "deepgramAPIKey",
        "geminiAPIKey",
        "licenseKey",
        "licenseData",
        "supabaseAnonKey",
        "enhancementUserID"
    ]

    // MARK: - Export

    func makeBackup(
        dictionary: DictionaryManager = .shared,
        powerModeManager: PowerModeManager = .shared,
        triggerRules: [TriggerWordRule],
        fillerWords: [String],
        preferences: [String: String] = ConfigurationBackupManager.currentPreferences(),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        now: Date = Date()
    ) throws -> Data {
        let backup = Backup(
            schemaVersion: Self.currentSchemaVersion,
            appVersion: appVersion,
            exportedAt: now,
            dictionary: try dictionary.makeExport(),
            powerModes: powerModeManager.powerModes,
            triggerRules: triggerRules,
            fillerWords: fillerWords,
            preferences: preferences.filter { Self.allowedPreferenceKeys.contains($0.key) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func currentPreferences(defaults: UserDefaults = .standard) -> [String: String] {
        var result: [String: String] = [:]
        for key in allowedPreferenceKeys {
            // Only string-valued preferences are portable this way; bools and
            // enums round-trip through their string form.
            if let value = defaults.object(forKey: key) {
                if let string = value as? String {
                    result[key] = string
                } else if let bool = value as? Bool {
                    result[key] = bool ? "true" : "false"
                } else if let number = value as? NSNumber {
                    result[key] = number.stringValue
                }
            }
        }
        return result
    }

    // MARK: - Import

    struct ImportSummary {
        var powerModesAdded = 0
        var triggerRulesAdded = 0
        var fillerWordsAdded = 0
        var preferencesApplied = 0
        var dictionaryReplacementsAdded = 0
        var dictionarySpellingsAdded = 0
    }

    enum ImportError: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema(let version):
                return "This backup was made by a newer EchoTune (schema \(version)). Update EchoTune to import it."
            }
        }
    }

    static func decodeBackup(from data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Backup.self, from: data)
    }

    /// Merges a backup into this Mac's configuration. Existing entries win:
    /// importing the same file twice must not duplicate anything.
    func importBackup(
        from data: Data,
        dictionary: DictionaryManager = .shared,
        powerModeManager: PowerModeManager = .shared,
        defaults: UserDefaults = .standard
    ) throws -> (summary: ImportSummary, triggerRules: [TriggerWordRule]) {
        let backup = try Self.decodeBackup(from: data)
        guard backup.schemaVersion <= Self.currentSchemaVersion else {
            throw ImportError.unsupportedSchema(backup.schemaVersion)
        }

        var summary = ImportSummary()

        // Dictionary: merge by written form, so a re-import is a no-op.
        let dictCounts = try dictionary.mergeExport(backup.dictionary)
        summary.dictionaryReplacementsAdded = dictCounts.replacements
        summary.dictionarySpellingsAdded = dictCounts.spellings

        // Power modes: merge by name.
        let existingNames = Set(powerModeManager.powerModes.map { $0.name.lowercased() })
        for mode in backup.powerModes where !existingNames.contains(mode.name.lowercased()) {
            powerModeManager.powerModes.append(mode)
            summary.powerModesAdded += 1
        }
        if summary.powerModesAdded > 0 {
            powerModeManager.persist()
        }

        // Trigger rules: merged by the caller (they are owned by
        // AIEnhancementEngine); return them so it can apply the merge.
        let existingPhrases = Set(backup.triggerRules.map { $0.triggerPhrase.lowercased() })
        let incomingRules = backup.triggerRules.filter { _ in true }
        summary.triggerRulesAdded = existingPhrases.count

        // Filler words: shared manager already dedupes.
        for word in backup.fillerWords where FillerWordManager.shared.addFiller(word) {
            summary.fillerWordsAdded += 1
        }

        // Preferences: allow-listed only, applied verbatim.
        for (key, value) in backup.preferences where Self.allowedPreferenceKeys.contains(key) {
            guard !Self.forbiddenPreferenceKeys.contains(key) else { continue }
            defaults.set(value, forKey: key)
            summary.preferencesApplied += 1
        }

        return (summary, incomingRules)
    }

    // MARK: - History CSV (RFC 4180)

    /// Escapes one CSV field per RFC 4180: wrap in quotes when the value
    /// contains a comma, quote or newline, and double any embedded quote.
    static func csvField(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func csvRow(_ values: [String]) -> String {
        values.map(csvField).joined(separator: ",")
    }

    /// Builds a transcript export. Word count is derived from the inserted text,
    /// not from the raw transcript, so the file matches what the user saw.
    func historyCSV(items: [TranscriptionHistoryItem]) -> String {
        var lines: [String] = []
        lines.append(Self.csvRow(["date_iso8601", "duration_seconds", "word_count", "detected_language", "text", "original_text"]))

        let formatter = ISO8601DateFormatter()
        for item in items {
            let wordCount = item.text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
            lines.append(Self.csvRow([
                formatter.string(from: item.date),
                String(format: "%.2f", item.duration),
                String(wordCount),
                item.detectedLanguage ?? "",
                item.text,
                item.originalText
            ]))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }
}