// MARK: - Final Result Assembly (segment-wise)
//
// Joins the committed live-tick segments plus the decoded tail, then runs
// hallucination filtering and processText once over the combined text.
// This REPLACES the old whole-recording re-decode path in
// endStreamingTranscription: at stop we only decode the <4s tail, so
// end-to-end latency no longer scales with recording length.

import Foundation
import WhisperKit
import os.log

extension WhisperEngine {

    /// Called from endStreamingTranscription instead of the old full re-decode.
    /// Joins committed live segments + tail, runs hallucination filtering and
    /// processText once over the combined text, and delivers the final result.
    func deliverFinalResult(segments: [String], tailText: String?,
                            completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) {
        // Drop segments that are pure Whisper silence hallucinations
        let hallucinations: Set<String> = [
            "thank you", "thanks", "thank you.", "thanks.",
            "thanks for watching", "thanks for watching.",
            "you", "thank", "bye", "goodbye", "bye.",
            "goodbye.", "...", ".", "so", "the", "and",
            "uh", "um", "hmm", "huh", "oh",
            "subtitle", "subtitles", "subscribe",
            "please subscribe", "like and subscribe"
        ]

        var parts = segments.filter { s in
            !s.isEmpty && !hallucinations.contains(s.lowercased())
        }
        if let tail = tailText, !tail.isEmpty, !hallucinations.contains(tail.lowercased()) {
            parts.append(tail)
        }

        let combined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !combined.isEmpty else {
            os_log("❌ All segments hallucination-filtered", log: wLog, type: .error)
            completion(.failure(.noAudioData))
            return
        }

        let processedText = TranscriptionEngine.shared.processText(combined)

        // Committed segments (already decoded while speaking) flow to the UI
        // coordinator so insertion can START immediately; any tail delta in
        // outputText then follows within ~1-2s.
        let committedPrefix = segments.filter { s in
            !s.isEmpty && !hallucinations.contains(s.lowercased())
        }.joined(separator: " ")

        let finalResult = WhisperTranscriptionResult(
            outputText: processedText,
            originalText: combined,
            translatedText: nil,
            detectedLanguage: nil,
            committedPrefix: committedPrefix
        )

        Task { @MainActor in
            self.currentText = finalResult.outputText
            self.isProcessing = false
            os_log("✅ Final cleaned: '%@'", log: wLog, type: .info, finalResult.outputText)
            completion(.success(finalResult))
        }
    }
}
