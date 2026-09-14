//
//  EchoMemoryManager.swift
//  EchoTune
//
//  Local memory for the Personal Operating Model:
//  - Stores transcripts with outcome metadata (edited, accepted, model used, etc.)
//  - Builds a compact user profile (frequent topics, average length, preferred model)
//  - Provides a coach that suggests one actionable insight at a time.
//

import Foundation
import Combine

private let memoryKey = "echoMemoryData"
private let profileKey = "echoProfileData"
/// Raw transcript payload kept aside when part of the stored blob was unreadable.
private let memoryUnreadableKey = "echoMemoryDataUnreadable"

/// Represents a single stored memory entry (one transcription + its outcome).
nonisolated struct EchoMemoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let text: String
    let duration: TimeInterval
    let modelID: String?          // e.g. "distil-whisper_distil-large-v3_turbo"
    let provider: String?         // "local", "groq", "deepgram", etc.
    var wasEdited: Bool           // user edited the final text after insertion
    var wasAccepted: Bool         // user gave explicit positive feedback (future)
    var wasRejected: Bool         // user gave explicit negative feedback (future)
    // Additional context: frontmost app, window title, etc.
    let frontmostApp: String?
    let windowTitle: String?
}

/// Aggregated profile derived from memory entries.
struct EchoProfile: Codable {
    var totalTranscriptions: Int
    var totalDuration: TimeInterval
    var averageLength: Double     // average words per transcription
    var mostUsedModel: String?
    var frequentTopics: [String]  // top N keywords from transcriptions
    var lastUpdated: Date
}

/// Coach insight: a single, actionable suggestion based on the profile.
struct EchoCoachInsight: Codable {
    let message: String
    let actionTitle: String?
    let action: String?           // e.g. "openSettings", "setHotkey"
}

class EchoMemoryManager: ObservableObject {
    static let shared = EchoMemoryManager()

    @Published var entries: [EchoMemoryEntry] = []
    @Published var profile: EchoProfile = .empty
    @Published var coachInsight: EchoCoachInsight?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadEntries()
        loadProfile()
        updateProfile()
        updateCoach()
        // Commitment memory is confirmation-gated. Existing transcripts remain
        // ordinary dictation and are not silently converted into tasks.
    }

    // MARK: - Public API

    /// Record a new transcription entry.
    func recordTranscription(
        text: String,
        duration: TimeInterval,
        modelID: String?,
        provider: String?,
        frontmostApp: String? = nil,
        windowTitle: String? = nil
    ) -> UUID {
        let entry = EchoMemoryEntry(
            id: UUID(),
            date: Date(),
            text: text,
            duration: duration,
            modelID: modelID,
            provider: provider,
            wasEdited: false,
            wasAccepted: false,
            wasRejected: false,
            frontmostApp: frontmostApp,
            windowTitle: windowTitle
        )
        entries.insert(entry, at: 0)
        saveEntries()
        updateProfile()
        updateCoach()
        return entry.id

    }

    /// Outcome of decoding the stored transcript blob.
    nonisolated struct MemoryDecodeResult {
        let entries: [EchoMemoryEntry]
        /// Set when part (or all) of the blob could not be decoded, so the
        /// caller can preserve the original bytes instead of overwriting them.
        let unreadablePayload: Data?
    }

    /// Decode stored transcriptions one record at a time, so a single bad
    /// record can never cost the whole history.
    nonisolated static func decodeEntries(from data: Data) -> MemoryDecodeResult {
        if let decoded = try? JSONDecoder().decode([EchoMemoryEntry].self, from: data) {
            return MemoryDecodeResult(entries: decoded, unreadablePayload: nil)
        }

        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            // Not even an array of records — keep every byte for the user.
            return MemoryDecodeResult(entries: [], unreadablePayload: data)
        }

        var recovered: [EchoMemoryEntry] = []
        var lostOne = false
        for element in raw {
            guard let elementData = try? JSONSerialization.data(withJSONObject: element),
                  let entry = try? JSONDecoder().decode(EchoMemoryEntry.self, from: elementData) else {
                lostOne = true
                continue
            }
            recovered.append(entry)
        }
        return MemoryDecodeResult(entries: recovered, unreadablePayload: lostOne ? data : nil)
    }

    /// Mark an entry as edited (user changed the text after insertion).
    func markEntryAsEdited(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].wasEdited = true
        saveEntries()
        updateProfile()
        updateCoach()
    }

    /// Provide explicit feedback (accept/reject) — future extension.
    func markEntryOutcome(id: UUID, accepted: Bool, rejected: Bool) {
        // Stub for future UI.
    }

    /// Refresh the profile and coach (called after loading).
    func refresh() {
        updateProfile()
        updateCoach()
    }

    // MARK: - Persistence

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: memoryKey) else { return }
        let result = EchoMemoryManager.decodeEntries(from: data)
        entries = result.entries
        if let payload = result.unreadablePayload {
            // Keep the original bytes: the next save rewrites this key, and a
            // single unreadable record must not cost the whole history.
            UserDefaults.standard.set(payload, forKey: memoryUnreadableKey)
            debugLog("⚠️ EchoMemoryManager: recovered \(result.entries.count) entries, parked the unreadable payload in \(memoryUnreadableKey)")
        }
    }

    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: memoryKey)
        } catch {
            debugLog("❌ EchoMemoryManager: failed to encode entries: \(error)")
        }
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileKey) else { return }
        do {
            profile = try JSONDecoder().decode(EchoProfile.self, from: data)
        } catch {
            debugLog("❌ EchoMemoryManager: failed to decode profile: \(error)")
            profile = .empty
        }
    }

    private func saveProfile() {
        do {
            let data = try JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: profileKey)
        } catch {
            debugLog("❌ EchoMemoryManager: failed to encode profile: \(error)")
        }
    }

    // MARK: - Profile Derivation

    private func updateProfile() {
        guard !entries.isEmpty else {
            profile = .empty
            saveProfile()
            return
        }

        let total = entries.count
        let totalDur = entries.reduce(0) { $0 + $1.duration }
        let avgLen = Double(entries.reduce(0) { $0 + $1.text.split(separator: " ").count }) / Double(total)

        // Most used model
        var modelCounts: [String: Int] = [:]
        for entry in entries {
            if let model = entry.modelID {
                modelCounts[model, default: 0] += 1
            }
        }
        let mostUsed = modelCounts.max(by: { $0.value < $1.value })?.key

        // Frequent topics: simple word frequency extraction
        let stopwords = Set(["the", "a", "an", "of", "to", "for", "with", "on", "at", "from", "by", "in", "as", "or", "and", "but", "not", "so", "for", "is", "are", "was", "were"])
        var wordCounts: [String: Int] = [:]
        for entry in entries {
            let words = entry.text.lowercased().split(separator: " ").map(String.init)
            for word in words where word.count > 2 && !stopwords.contains(word) {
                wordCounts[word, default: 0] += 1
            }
        }
        let sortedWords = wordCounts.sorted { $0.value > $1.value }
        let topWords = sortedWords.prefix(5).map { $0.key }

        profile = EchoProfile(
            totalTranscriptions: total,
            totalDuration: totalDur,
            averageLength: avgLen,
            mostUsedModel: mostUsed,
            frequentTopics: topWords,
            lastUpdated: Date()
        )
        saveProfile()
    }

    // MARK: - Coach

    private func updateCoach() {
        guard !entries.isEmpty else {
            coachInsight = EchoCoachInsight(
                message: "Start dictating to build your Echo profile.",
                actionTitle: nil,
                action: nil
            )
            return
        }

        // Simple heuristics for a first coach insight.
        let total = profile.totalTranscriptions
        let avgLen = profile.averageLength

        if total >= 10 && avgLen < 20 {
            coachInsight = EchoCoachInsight(
                message: "Your transcriptions are quite short. Consider dictating full sentences for better context.",
                actionTitle: nil,
                action: nil
            )
        } else if total >= 20 && profile.mostUsedModel == nil {
            coachInsight = EchoCoachInsight(
                message: "You're using multiple models — try sticking to one for more consistent results.",
                actionTitle: nil,
                action: nil
            )
        } else if total >= 5 {
            coachInsight = EchoCoachInsight(
                message: "You've transcribed \(total) times. Keep going — the more you use EchoTune, the better it understands your voice.",
                actionTitle: nil,
                action: nil
            )
        } else {
            coachInsight = EchoCoachInsight(
                message: "Welcome! Your Echo profile is being built as you dictate.",
                actionTitle: nil,
                action: nil
            )
        }
    }

    // MARK: - Clear (future)
    func clearAll() {
        entries.removeAll()
        profile = .empty
        coachInsight = nil
        saveEntries()
        saveProfile()
        // Tasks are mined from these transcriptions — drop them together so
        // clearing memory never leaves orphan records behind.
        CommitmentMemoryManager.shared.clearAll()
    }
}

extension EchoProfile {
    static var empty: EchoProfile {
        EchoProfile(
            totalTranscriptions: 0,
            totalDuration: 0,
            averageLength: 0,
            mostUsedModel: nil,
            frequentTopics: [],
            lastUpdated: Date()
        )
    }
}