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

/// Represents a single stored memory entry (one transcription + its outcome).
struct EchoMemoryEntry: Codable, Identifiable {
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
    ) {
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
        do {
            entries = try JSONDecoder().decode([EchoMemoryEntry].self, from: data)
        } catch {
            debugLog("❌ EchoMemoryManager: failed to decode entries: \(error)")
            entries = []
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