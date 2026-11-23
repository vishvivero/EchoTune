import Foundation
import Testing
@testable import EchoTune

/// ET-764 · multi-Mac settings backup + history CSV export.
struct ConfigurationBackupManagerTests {

    private func sampleMode(_ name: String) -> PowerMode {
        PowerMode(
            id: UUID(),
            name: name,
            emoji: "🎯",
            isEnabled: true,
            priority: 1,
            appBundleIdentifiers: ["com.tinyspeck.slackmacgap"],
            websitePatterns: ["*.slack.com"],
            useWhisper: true
        )
    }

    private func sampleRule(_ phrase: String) -> TriggerWordRule {
        TriggerWordRule(triggerPhrase: phrase, enhancementPrompt: "make it terse")
    }

    // MARK: Round trip

    @Test func backupRoundTripsConfiguration() throws {
        let manager = ConfigurationBackupManager.shared
        let dictionary = DictionaryManager.shared
        let powerModes = PowerModeManager.shared

        let data = try manager.makeBackup(
            dictionary: dictionary,
            powerModeManager: powerModes,
            triggerRules: [sampleRule("simplify")],
            fillerWords: ["like", "y'know"],
            preferences: ["preferredLanguage": "en-GB", "fillerRemovalEnabled": "true"]
        )

        let decoded = try ConfigurationBackupManager.decodeBackup(from: data)
        #expect(decoded.schemaVersion == ConfigurationBackupManager.currentSchemaVersion)
        #expect(decoded.triggerRules.count == 1)
        #expect(decoded.triggerRules.first?.triggerPhrase == "simplify")
        #expect(decoded.fillerWords.contains("like"))
        #expect(decoded.preferences["preferredLanguage"] == "en-GB")
        #expect(!decoded.appVersion.isEmpty)
    }

    @Test func backupNeverContainsSecrets() throws {
        let data = try ConfigurationBackupManager.shared.makeBackup(
            triggerRules: [],
            fillerWords: [],
            preferences: [
                "preferredLanguage": "en-US",
                // These must be stripped even if a caller passes them in.
                "groqAPIKey": "gsk_should_not_leak",
                "openaiAPIKey": "sk-should-not-leak",
                "licenseKey": "LICENSE-SHOULD-NOT-LEAK"
            ]
        )

        let text = try #require(String(data: data, encoding: .utf8))
        for secret in ["gsk_should_not_leak", "sk-should-not-leak", "LICENSE-SHOULD-NOT-LEAK"] {
            #expect(!text.contains(secret), "backup leaked \(secret)")
        }

        let decoded = try ConfigurationBackupManager.decodeBackup(from: data)
        for key in decoded.preferences.keys {
            #expect(!ConfigurationBackupManager.forbiddenPreferenceKeys.contains(key),
                    "\(key) must never be written to a backup")
        }
    }

    @Test func forbiddenKeysAreNotInTheAllowList() {
        for key in ConfigurationBackupManager.forbiddenPreferenceKeys {
            #expect(!ConfigurationBackupManager.allowedPreferenceKeys.contains(key),
                    "\(key) must not be allow-listed for backup")
        }
    }

    // MARK: Idempotency

    @Test func importingTwiceAddsNothingTheSecondTime() throws {
        let manager = ConfigurationBackupManager.shared
        let defaults = UserDefaults(suiteName: "backup-test-\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: "backup-test") }

        let mode = sampleMode("Slack Mode \(UUID().uuidString.prefix(6))")
        let filler = "filler-\(UUID().uuidString.prefix(6))"
        let spelling = CorrectSpelling(word: "RoundTrip\(UUID().uuidString.prefix(4))")

        let dictionaryExport = DictionaryManager.DictionaryExport(
            version: "1.0",
            exportDate: Date(),
            wordReplacements: [],
            correctSpellings: [spelling]
        )
        let backup = ConfigurationBackupManager.Backup(
            schemaVersion: ConfigurationBackupManager.currentSchemaVersion,
            appVersion: "7.7.8",
            exportedAt: Date(),
            dictionary: dictionaryExport,
            powerModes: [mode],
            triggerRules: [],
            fillerWords: [filler.lowercased()],
            preferences: ["preferredLanguage": "en-US"]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let first = try manager.importBackup(from: data, defaults: defaults)
        let second = try manager.importBackup(from: data, defaults: defaults)

        #expect(first.summary.powerModesAdded == 1)
        #expect(second.summary.powerModesAdded == 0, "re-import must not duplicate power modes")
        #expect(second.summary.dictionarySpellingsAdded == 0, "re-import must not duplicate spellings")
    }

    @Test func newerSchemaIsRejectedRatherThanMisread() throws {
        let backup = ConfigurationBackupManager.Backup(
            schemaVersion: ConfigurationBackupManager.currentSchemaVersion + 1,
            appVersion: "9.9.9",
            exportedAt: Date(),
            dictionary: .init(version: "1.0", exportDate: Date(), wordReplacements: [], correctSpellings: []),
            powerModes: [],
            triggerRules: [],
            fillerWords: [],
            preferences: [:]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        #expect(throws: ConfigurationBackupManager.ImportError.self) {
            _ = try ConfigurationBackupManager.shared.importBackup(
                from: data,
                defaults: UserDefaults(suiteName: "reject-test")!
            )
        }
    }

    // MARK: CSV / RFC 4180

    @Test func csvEscapesCommasQuotesAndNewlines() {
        #expect(ConfigurationBackupManager.csvField("plain") == "plain")
        #expect(ConfigurationBackupManager.csvField("a,b") == "\"a,b\"")
        #expect(ConfigurationBackupManager.csvField("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(ConfigurationBackupManager.csvField("line1\nline2") == "\"line1\nline2\"")
        #expect(ConfigurationBackupManager.csvField("") == "")
    }

    @Test func csvRowJoinsEscapedFields() {
        let row = ConfigurationBackupManager.csvRow(["a", "b,c", "d\"e"])
        #expect(row == "a,\"b,c\",\"d\"\"e\"")
    }

    @Test func historyCSVHasAHeaderAndOneRowPerItem() {
        let items = [
            TranscriptionHistoryItem(text: "Hello, world", duration: 3.5, originalText: "hello world", rawTranscriptionText: "hello world"),
            TranscriptionHistoryItem(text: "Say \"cheese\"\nplease", duration: 1.25, originalText: "say cheese please", rawTranscriptionText: "say cheese please")
        ]
        let csv = ConfigurationBackupManager.shared.historyCSV(items: items)
        let rows = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

        #expect(rows.count == 3, "header plus two records")
        #expect(rows[0].hasPrefix("date_iso8601,"))
        #expect(csv.contains("\"Hello, world\""), "comma inside text must be quoted")
        #expect(csv.contains("\"\"cheese\"\""), "quotes inside text must be doubled")
        #expect(csv.hasSuffix("\r\n"), "RFC 4180 trailing CRLF")
    }

    @Test func emptyHistoryStillProducesAHeader() {
        let csv = ConfigurationBackupManager.shared.historyCSV(items: [])
        #expect(csv.hasPrefix("date_iso8601,"))
        #expect(csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }.count == 1)
    }
}
