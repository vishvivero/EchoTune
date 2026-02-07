//
//  AudioChunker.swift
//  EchoTune
//
//  Splits long audio data into manageable chunks for transcription.
//  Handles Apple Speech's ~60s limit, Groq's 25MB file limit, and memory efficiency.
//

import Foundation
import AVFoundation

class AudioChunker {

    /// Configuration for chunking behavior
    struct ChunkConfig {
        /// Target duration per chunk in seconds
        let chunkDurationSeconds: TimeInterval

        /// Maximum file size per chunk in bytes (0 = no limit)
        let maxChunkSizeBytes: Int

        /// Overlap between chunks in seconds (helps avoid cutting words)
        let overlapSeconds: TimeInterval

        /// Default config for Apple Speech (conservative 25s chunks, well under 60s limit)
        static let appleSpeech = ChunkConfig(
            chunkDurationSeconds: 25,
            maxChunkSizeBytes: 0,
            overlapSeconds: 0.5
        )

        /// Default config for Groq (25s chunks, under 25MB limit)
        static let groq = ChunkConfig(
            chunkDurationSeconds: 25,
            maxChunkSizeBytes: 24 * 1024 * 1024, // 24MB (safety margin under 25MB)
            overlapSeconds: 0.5
        )

        /// Default config for Deepgram (longer chunks OK, Deepgram handles long audio)
        static let deepgram = ChunkConfig(
            chunkDurationSeconds: 60,
            maxChunkSizeBytes: 0,
            overlapSeconds: 0.5
        )

        /// Default config for Whisper (30s is Whisper's native window)
        static let whisper = ChunkConfig(
            chunkDurationSeconds: 30,
            maxChunkSizeBytes: 0,
            overlapSeconds: 0.5
        )
    }

    /// Result of chunking audio data
    struct ChunkResult {
        let chunks: [Data]
        let totalDuration: TimeInterval
        let chunkDurations: [TimeInterval]
    }

    // MARK: - Public API

    /// Splits audio data into chunks based on the provided configuration.
    /// Returns the original data as a single chunk if it's already short enough.
    static func chunkAudioData(
        _ audioData: Data,
        sampleRate: Double,
        channelCount: Int,
        bytesPerSample: Int,
        config: ChunkConfig
    ) -> ChunkResult {
        let bytesPerFrame = bytesPerSample * channelCount
        let totalFrames = audioData.count / bytesPerFrame
        let totalDuration = Double(totalFrames) / sampleRate

        print("🔪 AudioChunker: totalDuration=\(String(format: "%.1f", totalDuration))s, config.chunkDuration=\(config.chunkDurationSeconds)s")

        // If audio is short enough, return as single chunk
        if totalDuration <= config.chunkDurationSeconds * 1.1 { // 10% tolerance
            print("   → Audio is short enough, returning as single chunk")
            return ChunkResult(
                chunks: [audioData],
                totalDuration: totalDuration,
                chunkDurations: [totalDuration]
            )
        }

        // Calculate chunk parameters
        let framesPerChunk = Int(sampleRate * config.chunkDurationSeconds)
        let overlapFrames = Int(sampleRate * config.overlapSeconds)
        let bytesPerChunk = framesPerChunk * bytesPerFrame

        var chunks: [Data] = []
        var chunkDurations: [TimeInterval] = []
        var offset = 0

        while offset < audioData.count {
            let remaining = audioData.count - offset
            let chunkSize = min(bytesPerChunk, remaining)

            // Also respect max chunk size if configured
            let finalChunkSize: Int
            if config.maxChunkSizeBytes > 0 && chunkSize > config.maxChunkSizeBytes {
                finalChunkSize = config.maxChunkSizeBytes
            } else {
                finalChunkSize = chunkSize
            }

            let chunkData = audioData.subdata(in: offset..<(offset + finalChunkSize))
            chunks.append(chunkData)

            let chunkFrames = finalChunkSize / bytesPerFrame
            let chunkDuration = Double(chunkFrames) / sampleRate
            chunkDurations.append(chunkDuration)

            // Advance by chunk size minus overlap
            let advanceBytes = max(bytesPerFrame, finalChunkSize - (overlapFrames * bytesPerFrame))
            offset += advanceBytes
        }

        print("   → Split into \(chunks.count) chunks: \(chunkDurations.map { String(format: "%.1fs", $0) }.joined(separator: ", "))")

        return ChunkResult(
            chunks: chunks,
            totalDuration: totalDuration,
            chunkDurations: chunkDurations
        )
    }

    /// Splits audio buffers into chunks of PCM buffers.
    /// Used for Whisper engine which works with Float arrays.
    static func chunkBuffers(
        _ buffers: [AVAudioPCMBuffer],
        config: ChunkConfig
    ) -> [[AVAudioPCMBuffer]] {
        guard !buffers.isEmpty else { return [] }

        let sampleRate = buffers[0].format.sampleRate
        let framesPerChunk = AVAudioFrameCount(sampleRate * config.chunkDurationSeconds)

        // Calculate total frames
        let totalFrames = buffers.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        let totalDuration = Double(totalFrames) / sampleRate

        // If short enough, return as single chunk
        if totalDuration <= config.chunkDurationSeconds * 1.1 {
            return [buffers]
        }

        var chunks: [[AVAudioPCMBuffer]] = []
        var currentChunkBuffers: [AVAudioPCMBuffer] = []
        var currentChunkFrames: AVAudioFrameCount = 0

        for buffer in buffers {
            currentChunkBuffers.append(buffer)
            currentChunkFrames += buffer.frameLength

            if currentChunkFrames >= framesPerChunk {
                chunks.append(currentChunkBuffers)
                currentChunkBuffers = []
                currentChunkFrames = 0
            }
        }

        // Don't forget the last partial chunk
        if !currentChunkBuffers.isEmpty {
            chunks.append(currentChunkBuffers)
        }

        print("🔪 AudioChunker: Split \(buffers.count) buffers into \(chunks.count) buffer-chunks")
        return chunks
    }

    /// Merges multiple transcription results into a single string.
    /// Handles overlap by removing duplicate words at chunk boundaries.
    static func mergeTranscriptions(_ transcriptions: [String]) -> String {
        guard !transcriptions.isEmpty else { return "" }
        if transcriptions.count == 1 { return transcriptions[0] }

        var merged = transcriptions[0].trimmingCharacters(in: .whitespacesAndNewlines)

        for i in 1..<transcriptions.count {
            let next = transcriptions[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !next.isEmpty else { continue }

            // Try to detect and remove overlapping words at the boundary
            let prevWords = merged.split(separator: " ")
            let nextWords = next.split(separator: " ")

            // Check last N words of previous chunk against first N words of next chunk
            let overlapCheckCount = min(5, min(prevWords.count, nextWords.count))
            var bestOverlap = 0

            for overlapLen in 1...overlapCheckCount {
                let prevSuffix = prevWords.suffix(overlapLen).map(String.init)
                let nextPrefix = nextWords.prefix(overlapLen).map(String.init)

                if prevSuffix.map({ $0.lowercased() }) == nextPrefix.map({ $0.lowercased() }) {
                    bestOverlap = overlapLen
                }
            }

            if bestOverlap > 0 {
                // Remove overlapping words from the next chunk
                let trimmedNext = nextWords.dropFirst(bestOverlap).map(String.init).joined(separator: " ")
                if !trimmedNext.isEmpty {
                    merged += " " + trimmedNext
                }
            } else {
                merged += " " + next
            }
        }

        return merged
    }
}
