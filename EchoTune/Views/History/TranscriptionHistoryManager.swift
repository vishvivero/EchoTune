//
//  TranscriptionHistoryManager.swift
//  EchoTune
//
//  Created by Vishnu Raj on 27/10/2025.
//

import Foundation
import Combine

class TranscriptionHistoryManager: ObservableObject {
    static let shared = TranscriptionHistoryManager()
    
    @Published var transcriptions: [TranscriptionHistoryItem] = []
    
    private let historyKey = "transcriptionHistoryData"
    
    static var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("EchoTune", isDirectory: true)
        let recordingsDir = appSupportDir.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true, attributes: nil)
        return recordingsDir
    }
    
    private init() {
        loadTranscriptions()
    }
    
    func saveAudioFile(data: Data, id: UUID) -> String? {
        let fileURL = Self.recordingsDirectory.appendingPathComponent("\(id.uuidString).caf")
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            debugLog("❌ TranscriptionHistoryManager: Failed to save audio file: \(error)")
            return nil
        }
    }
    
    func totalAudioStorageSize() -> Int64 {
        var total: Int64 = 0
        for item in transcriptions {
            if let path = item.audioFilePath,
               let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    func deleteTranscription(_ item: TranscriptionHistoryItem) {
        if let path = item.audioFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        transcriptions.removeAll { $0.id == item.id }
        saveTranscriptions()
    }
    
    func deleteAudioFile(for item: TranscriptionHistoryItem) {
        if let path = item.audioFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        if let index = transcriptions.firstIndex(where: { $0.id == item.id }) {
            transcriptions[index].audioFilePath = nil
            saveTranscriptions()
        }
    }
    
    func updateTranscriptionText(for item: TranscriptionHistoryItem, newText: String) {
        if let index = transcriptions.firstIndex(where: { $0.id == item.id }) {
            transcriptions[index].text = newText
            if transcriptions[index].processingMetadata != nil {
                transcriptions[index].processingMetadata?.userEdited = true
            } else {
                transcriptions[index].processingMetadata = TranscriptionProcessingMetadata(userEdited: true)
            }
            saveTranscriptions()
        }
    }
    
    func clearAll() {
        for item in transcriptions {
            if let path = item.audioFilePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        transcriptions.removeAll()
        saveTranscriptions()
    }
    
    func updateTranscriptionDetails(
        for item: TranscriptionHistoryItem,
        newText: String,
        rawTranscriptionText: String,
        processingMetadata: TranscriptionProcessingMetadata?
    ) {
        if let index = transcriptions.firstIndex(where: { $0.id == item.id }) {
            transcriptions[index].text = newText
            transcriptions[index].rawTranscriptionText = rawTranscriptionText
            transcriptions[index].processingMetadata = processingMetadata
            saveTranscriptions()
        }
    }
    
    func clearAudioPath(for id: UUID) {
        if let index = transcriptions.firstIndex(where: { $0.id == id }) {
            transcriptions[index].audioFilePath = nil
            saveTranscriptions()
        }
    }
    
    @discardableResult
    func addTranscription(
        _ text: String,
        duration: TimeInterval,
        audioFilePath: String?,
        originalText: String,
        translatedText: String?,
        detectedLanguage: String?,
        rawTranscriptionText: String,
        processingMetadata: TranscriptionProcessingMetadata
    ) -> TranscriptionHistoryItem {
        let item = TranscriptionHistoryItem(
            text: text,
            duration: duration,
            audioFilePath: audioFilePath,
            originalText: originalText,
            translatedText: translatedText,
            detectedLanguage: detectedLanguage,
            rawTranscriptionText: rawTranscriptionText,
            processingMetadata: processingMetadata
        )
        transcriptions.insert(item, at: 0)
        saveTranscriptions()
        return item
    }
    
    func updateProcessingMetadata(for id: UUID, _ block: (inout TranscriptionProcessingMetadata) -> Void) {
        if let index = transcriptions.firstIndex(where: { $0.id == id }) {
            var metadata = transcriptions[index].processingMetadata ?? TranscriptionProcessingMetadata()
            block(&metadata)
            transcriptions[index].processingMetadata = metadata
            saveTranscriptions()
        }
    }
    
    private func loadTranscriptions() {
        if let data = UserDefaults.standard.data(forKey: historyKey) {
            do {
                transcriptions = try JSONDecoder().decode([TranscriptionHistoryItem].self, from: data)
            } catch {
                debugLog("❌ TranscriptionHistoryManager: Failed to decode history: \(error)")
                transcriptions = []
            }
        }
    }
    
    private func saveTranscriptions() {
        do {
            let data = try JSONEncoder().encode(transcriptions)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            debugLog("❌ TranscriptionHistoryManager: Failed to encode history: \(error)")
        }
    }
}
