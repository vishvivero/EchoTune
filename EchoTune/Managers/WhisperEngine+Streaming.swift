//
//  WhisperEngine+Streaming.swift
//  EchoTune
//
//  Streaming transcription methods for WhisperEngine.
//  Handles live audio buffer accumulation and batch transcription.
//
//  Created by Vishnu Raj on 26/10/2025.
//

import Foundation
import AVFoundation
import WhisperKit
import os.log

// MARK: - Streaming Transcription
//
// Segment-wise streaming: every 4s tick transcribes ONLY the audio recorded
// since the previous tick (instead of re-transcribing the whole recording),
// and appends the result to liveSegmentTranscripts. On stop, only the final
// tail is transcribed and the cached segments are joined. This makes
// end-to-end latency O(tail) instead of O(entire recording).

extension WhisperEngine {

    /// Interval in seconds between live transcription updates
    private static let liveTranscriptionInterval: TimeInterval = 4.0

    func startStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) {
        os_log("🎤 startStreamingTranscription, whisperKit=%{public}@, isAvailable=%d", log: wLog, type: .info, whisperKitRef == nil ? "nil" : "loaded", isAvailable ? 1 : 0)
        guard whisperKitRef != nil else {
            os_log("❌ whisperKit is nil — modelNotLoaded", log: wLog, type: .error)
            completion(.failure(.modelNotLoaded))
            return
        }

        isProcessing = true
        currentText = ""
        audioBuffers = []
        liveTranscriptAccumulated = ""
        lastLiveTranscribedBufferCount = 0
        isLiveTranscribing = false
        liveSegmentTranscripts = []

        debugLog("🎤 Starting streaming transcription...")
        startLiveTranscriptionTimer()
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        audioProcessingQueueRef.async { [weak self] in
            guard let self = self else { return }
            self.audioBuffers.append(buffer)
        }
    }

    // MARK: - Live Transcription Timer

    private func startLiveTranscriptionTimer() {
        stopLiveTranscriptionTimer()
        DispatchQueue.main.async { [weak self] in
            self?.liveTranscriptionTimer = Timer.scheduledTimer(withTimeInterval: Self.liveTranscriptionInterval, repeats: true) { [weak self] _ in
                self?.processLiveTranscriptionChunk()
            }
        }
    }

    func stopLiveTranscriptionTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.liveTranscriptionTimer?.invalidate()
            self?.liveTranscriptionTimer = nil
        }
    }

    private func processLiveTranscriptionChunk() {
        guard !isLiveTranscribing else { return }
        guard let whisperKit = whisperKitRef else { return }

        // Snapshot ONLY the buffers recorded since the last committed tick.
        // (Previously this re-transcribed the entire recording every 4s —
        // O(n²) work that grew with recording length.)
        let (buffersSnapshot, bufferCount): ([AVAudioPCMBuffer], Int) = audioProcessingQueueRef.sync {
            let count = self.audioBuffers.count
            guard count > self.lastLiveTranscribedBufferCount else { return ([], count) }
            return (Array(self.audioBuffers[self.lastLiveTranscribedBufferCount...]), count)
        }

        guard !buffersSnapshot.isEmpty, bufferCount > lastLiveTranscribedBufferCount else { return }

        isLiveTranscribing = true

        Task {
            do {
                let audioArray = try self.convertBuffersToFloatArray(buffersSnapshot)

                // Quick RMS check — skip if too quiet
                let rms = sqrt(audioArray.map { $0 * $0 }.reduce(0, +) / Float(max(audioArray.count, 1)))
                guard rms > 0.001 else {
                    await MainActor.run {
                        self.isLiveTranscribing = false
                        self.lastLiveTranscribedBufferCount = bufferCount
                    }
                    return
                }

                let result = try await self.transcribeWithCurrentSettings(audioArray: audioArray, whisperKit: whisperKit)
                let text = result.outputText.trimmingCharacters(in: .whitespacesAndNewlines)

                // Filter Whisper hallucinations (common silence outputs)
                let hallucinations: Set<String> = [
                    "thank you", "thanks", "thank you.", "thanks.",
                    "thanks for watching", "thanks for watching.",
                    "you", "thank", "bye", "goodbye", "bye.",
                    "goodbye.", "...", ".", "so", "the", "and",
                    "uh", "um", "hmm", "huh", "oh",
                    "subtitle", "subtitles", "subscribe",
                    "please subscribe", "like and subscribe"
                ]

                await MainActor.run {
                    self.lastLiveTranscribedBufferCount = bufferCount
                    self.isLiveTranscribing = false

                    guard !text.isEmpty, !hallucinations.contains(text.lowercased()) else { return }

                    self.liveSegmentTranscripts.append(text)
                    self.liveTranscriptAccumulated = self.liveSegmentTranscripts.joined(separator: " ")

                    // Post live transcription update
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LiveTranscriptionUpdate"),
                        object: nil,
                        userInfo: ["text": self.liveTranscriptAccumulated]
                    )
                }
            } catch {
                await MainActor.run {
                    self.isLiveTranscribing = false
                    debugLog("⚠️ Live transcription chunk failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func endStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) {
        stopLiveTranscriptionTimer()
        debugLog("🛑 Ending streaming transcription (segment-wise)")
        os_log("🛑 endStreamingTranscription: buffers=%d committedSegments=%d whisperKit=%{public}@", log: wLog, type: .info,
               audioBuffers.count, liveSegmentTranscripts.count, whisperKitRef == nil ? "nil" : "loaded")

        guard let whisperKit = whisperKitRef else {
            os_log("❌ whisperKit nil at endStreaming", log: wLog, type: .error)
            isProcessing = false
            completion(.failure(.modelNotLoaded))
            return
        }

        // Synchronize with audioProcessingQueue to safely snapshot buffers.
        // Buffers already covered by committed live-tick segments are dropped;
        // only the tail recorded since the last committed tick is decoded.
        let tailBuffers: [AVAudioPCMBuffer] = audioProcessingQueueRef.sync {
            let committed = self.lastLiveTranscribedBufferCount
            let snapshot = committed < self.audioBuffers.count ? Array(self.audioBuffers[committed...]) : []
            self.audioBuffers = []
            return snapshot
        }

        let committedSegments = liveSegmentTranscripts

        // Nothing new since the last committed tick → deliver cached segments only.
        guard !tailBuffers.isEmpty else {
            guard !committedSegments.isEmpty else {
                os_log("❌ audioBuffers empty at endStreaming", log: wLog, type: .error)
                completion(.failure(.noAudioData))
                return
            }
            deliverFinalResult(segments: committedSegments, tailText: nil, completion: completion)
            return
        }

        Task {
            do {
                os_log("🔄 Task started: decoding tail of %d buffers", log: wLog, type: .info, tailBuffers.count)

                // Calculate total frames from tail buffers only
                let totalFrameCount = tailBuffers.reduce(0) { $0 + Int($1.frameLength) }
                let sampleRate = tailBuffers[0].format.sampleRate
                let audioDuration = Double(totalFrameCount) / sampleRate
                os_log("📊 Tail audio: %.2fs (%d frames, %.0fHz)", log: wLog, type: .info, audioDuration, totalFrameCount, sampleRate)

                // Convert tail buffers to a single Float array
                let audioArray = try self.convertBuffersToFloatArray(tailBuffers)
                os_log("✅ Converted tail to %d samples", log: wLog, type: .info, audioArray.count)

                // Start performance monitoring for transcription
                await MainActor.run {
                    PerformanceMonitor.shared.startTranscription(
                        engine: "WhisperKit",
                        model: self.loadedModelName ?? "unknown"
                    )
                }

                // Transcribe the tail (or short final) segment directly
                os_log("🎙️ Calling whisperKit.transcribe(audioArray:) for final tail...", log: wLog, type: .info)
                let tailResult = try await self.transcribeWithCurrentSettings(audioArray: audioArray, whisperKit: whisperKit)
                let tailText = tailResult.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                os_log("📝 Tail transcription: '%@'", log: wLog, type: .info, tailText)

                await MainActor.run {
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: tailResult.outputText.split(separator: " ").count
                    )
                }

                deliverFinalResult(segments: committedSegments, tailText: tailText.isEmpty ? nil : tailText,
                                   completion: completion)
            } catch {
                os_log("❌ Transcription Task FAILED: %{public}@", log: wLog, type: .error, "\(error)")
                await MainActor.run {
                    self.isProcessing = false

                    debugLog("❌ Streaming transcription failed: \(error)")
                    completion(.failure(.transcriptionFailed(error)))
                }
            }
        }
    }
}
