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
    var rawTranscriptionText: String?
    var processingMetadata: TranscriptionProcessingMetadata?

    init(
        text: String,
        date: Date,
        duration: TimeInterval,
        audioFilePath: String? = nil,
        originalText: String? = nil,
        translatedText: String? = nil,
        detectedLanguage: String? = nil,
        rawTranscriptionText: String? = nil,
        processingMetadata: TranscriptionProcessingMetadata? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedLanguage = detectedLanguage
        self.rawTranscriptionText = rawTranscriptionText
        self.processingMetadata = processingMetadata
    }

    init(
        id: UUID,
        text: String,
        date: Date,
        duration: TimeInterval,
        audioFilePath: String? = nil,
        originalText: String? = nil,
        translatedText: String? = nil,
        detectedLanguage: String? = nil,
        rawTranscriptionText: String? = nil,
        processingMetadata: TranscriptionProcessingMetadata? = nil
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedLanguage = detectedLanguage
        self.rawTranscriptionText = rawTranscriptionText
        self.processingMetadata = processingMetadata
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

    var transcriptionProviderLabel: String? {
        processingMetadata?.transcriptionProvider
    }

    var transcriptionModelLabel: String? {
        processingMetadata?.transcriptionModel
    }

    var enhancementProviderLabel: String? {
        processingMetadata?.enhancementProvider
    }

    var enhancementModelLabel: String? {
        processingMetadata?.enhancementModel
    }

    var hasEnhancement: Bool {
        processingMetadata?.hasEnhancement == true
    }

    var usedFallback: Bool {
        processingMetadata?.usedFallback == true
    }

    var fallbackReason: String? {
        processingMetadata?.fallbackReason
    }

    var hasDiagnostics: Bool {
        processingMetadata?.transcriptionLatency != nil ||
        processingMetadata?.enhancementLatency != nil ||
        processingMetadata?.textInsertionLatency != nil ||
        processingMetadata?.totalLatency != nil ||
        processingMetadata?.audioByteCount != nil ||
        processingMetadata?.usedFallback == true
    }

    var diagnosticsLine: String? {
        guard let metadata = processingMetadata else { return nil }
        var parts: [String] = []
        if let totalLatency = metadata.totalLatency {
            parts.append(String(format: "%.1fs total", totalLatency))
        }
        if let transcriptionLatency = metadata.transcriptionLatency {
            parts.append(String(format: "%.1fs transcribe", transcriptionLatency))
        }
        if let enhancementLatency = metadata.enhancementLatency {
            parts.append(String(format: "%.1fs enhance", enhancementLatency))
        }
        if let textInsertionLatency = metadata.textInsertionLatency {
            parts.append(String(format: "%.1fs insert", textInsertionLatency))
        }
        if metadata.usedFallback {
            parts.append(metadata.fallbackReason.map { "fallback: \($0)" } ?? "fallback")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
