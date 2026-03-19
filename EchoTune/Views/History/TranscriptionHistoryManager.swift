//
//  TranscriptionHistoryManager.swift
//  EchoTune
//
//  Extracted from HistoryView.swift
//

import Foundation
import Combine

// MARK: - History Manager

class TranscriptionHistoryManager: ObservableObject {
    static let shared = TranscriptionHistoryManager()

    @Published var transcriptions: [TranscriptionHistoryItem] = []

    private let userDefaults = UserDefaults.standard
    private let historyKey = "transcriptionHistory"

    /// Persistent recordings directory
    static var recordingsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recordingsDir = appSupport.appendingPathComponent("EchoTune/Recordings", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        return recordingsDir
    }

    /// Last transcription item (for quick access / paste last)
    var lastTranscription: TranscriptionHistoryItem? {
        transcriptions.first
    }

    private init() {
        loadHistory()
        ensureRecordingsDirectory()
    }

    private func ensureRecordingsDirectory() {
        let dir = TranscriptionHistoryManager.recordingsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                debugLog("📁 Created recordings directory: \(dir.path)")
            } catch {
                debugLog("❌ Failed to create recordings directory: \(error)")
            }
        }
    }

    func addTranscription(
        _ text: String,
        duration: TimeInterval,
        audioFilePath: String? = nil,
        originalText: String? = nil,
        translatedText: String? = nil,
        detectedLanguage: String? = nil
    ) {
        let item = TranscriptionHistoryItem(
            text: text,
            date: Date(),
            duration: duration,
            audioFilePath: audioFilePath,
            originalText: originalText,
            translatedText: translatedText,
            detectedLanguage: detectedLanguage
        )

        transcriptions.insert(item, at: 0) // Most recent first
        saveHistory()

        debugLog("📝 Added to history: \(text.prefix(50))... (audio: \(audioFilePath != nil ? "yes" : "no"))")
    }

    func updateTranscriptionText(for item: TranscriptionHistoryItem, newText: String) {
        if let index = transcriptions.firstIndex(where: { $0.id == item.id }) {
            transcriptions[index] = TranscriptionHistoryItem(
                id: item.id,
                text: newText,
                date: item.date,
                duration: item.duration,
                audioFilePath: item.audioFilePath,
                originalText: item.originalText,
                translatedText: item.translatedText,
                detectedLanguage: item.detectedLanguage
            )
            saveHistory()
            debugLog("📝 Updated transcription text for \(item.id)")
        }
    }

    func deleteTranscription(_ item: TranscriptionHistoryItem) {
        // Delete associated audio file if it exists
        if let audioPath = item.audioFilePath {
            try? FileManager.default.removeItem(atPath: audioPath)
            debugLog("🗑️ Deleted audio file: \(audioPath)")
        }

        transcriptions.removeAll { $0.id == item.id }
        saveHistory()
    }

    func deleteAudioFile(for item: TranscriptionHistoryItem) {
        guard let audioPath = item.audioFilePath else { return }

        // Stop playback if this file is playing
        if AudioPlayerManager.shared.currentlyPlayingId == item.id {
            AudioPlayerManager.shared.stop()
        }

        try? FileManager.default.removeItem(atPath: audioPath)
        debugLog("🗑️ Deleted audio file: \(audioPath)")

        // Update the item to remove audio path
        if let index = transcriptions.firstIndex(where: { $0.id == item.id }) {
            transcriptions[index] = TranscriptionHistoryItem(
                id: item.id,
                text: item.text,
                date: item.date,
                duration: item.duration,
                audioFilePath: nil,
                originalText: item.originalText,
                translatedText: item.translatedText,
                detectedLanguage: item.detectedLanguage
            )
            saveHistory()
        }
    }

    func clearAll() {
        // Delete all audio files
        for item in transcriptions {
            if let audioPath = item.audioFilePath {
                try? FileManager.default.removeItem(atPath: audioPath)
            }
        }

        transcriptions = []
        saveHistory()
    }

    /// Save audio data to the persistent recordings directory
    func saveAudioFile(data: Data, id: UUID) -> String? {
        let fileName = "\(id.uuidString).caf"
        let fileURL = TranscriptionHistoryManager.recordingsDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            debugLog("💾 Saved audio file: \(fileURL.path) (\(data.count) bytes)")
            return fileURL.path
        } catch {
            debugLog("❌ Failed to save audio file: \(error)")
            return nil
        }
    }

    /// Copy a temp audio file to the persistent recordings directory
    func copyAudioFile(from sourcePath: String, id: UUID) -> String? {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let fileName = "\(id.uuidString).caf"
        let destURL = TranscriptionHistoryManager.recordingsDirectory.appendingPathComponent(fileName)

        do {
            // Remove destination if it already exists
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            debugLog("💾 Copied audio file: \(destURL.path)")
            return destURL.path
        } catch {
            debugLog("❌ Failed to copy audio file: \(error)")
            return nil
        }
    }

    /// Calculate total storage used by audio files
    func totalAudioStorageSize() -> Int64 {
        var totalSize: Int64 = 0
        for item in transcriptions {
            if let path = item.audioFilePath,
               let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }

    /// Count of transcriptions that have audio files
    func audioFileCount() -> Int {
        return transcriptions.filter { item in
            guard let path = item.audioFilePath else { return false }
            return FileManager.default.fileExists(atPath: path)
        }.count
    }

    /// Remove audio path reference from a transcription item (keeps transcript, removes audio link)
    func clearAudioPath(for itemId: UUID) {
        if let index = transcriptions.firstIndex(where: { $0.id == itemId }) {
            let item = transcriptions[index]
            transcriptions[index] = TranscriptionHistoryItem(
                id: item.id,
                text: item.text,
                date: item.date,
                duration: item.duration,
                audioFilePath: nil,
                originalText: item.originalText,
                translatedText: item.translatedText,
                detectedLanguage: item.detectedLanguage
            )
            saveHistory()
        }
    }

    private func loadHistory() {
        if let data = userDefaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([TranscriptionHistoryItem].self, from: data) {
            transcriptions = decoded
            debugLog("📚 Loaded \(transcriptions.count) transcriptions from history")
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(transcriptions) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }
}
