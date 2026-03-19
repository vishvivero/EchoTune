//
//  TranscriptionHistoryItem.swift
//  EchoTune
//
//  Extracted from HistoryView.swift
//

import Foundation

// MARK: - History Item Model

struct TranscriptionHistoryItem: Identifiable, Codable {
    let id: UUID
    var text: String
    let date: Date
    let duration: TimeInterval
    var audioFilePath: String?
    var originalText: String?
    var translatedText: String?
    var detectedLanguage: String?

    init(
        text: String,
        date: Date,
        duration: TimeInterval,
        audioFilePath: String? = nil,
        originalText: String? = nil,
        translatedText: String? = nil,
        detectedLanguage: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedLanguage = detectedLanguage
    }

    init(
        id: UUID,
        text: String,
        date: Date,
        duration: TimeInterval,
        audioFilePath: String? = nil,
        originalText: String? = nil,
        translatedText: String? = nil,
        detectedLanguage: String? = nil
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedLanguage = detectedLanguage
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var hasAudioFile: Bool {
        guard let path = audioFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}
