//
//  TranscriptionHistoryItem.swift
//  EchoTune
//
//  Created by Vishnu Raj on 27/10/2025.
//

import Foundation

struct TranscriptionHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    var text: String
    var audioFilePath: String?
    let originalText: String
    let translatedText: String?
    let detectedLanguage: String?
    var rawTranscriptionText: String
    var processingMetadata: TranscriptionProcessingMetadata?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        text: String,
        duration: TimeInterval,
        audioFilePath: String? = nil,
        originalText: String,
        translatedText: String? = nil,
        detectedLanguage: String? = nil,
        rawTranscriptionText: String,
        processingMetadata: TranscriptionProcessingMetadata? = nil
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedLanguage = detectedLanguage
        self.rawTranscriptionText = rawTranscriptionText
        self.processingMetadata = processingMetadata
    }
}
