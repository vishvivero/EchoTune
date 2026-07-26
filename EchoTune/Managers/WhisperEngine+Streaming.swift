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

extension WhisperEngine {

    /// Interval in seconds between live transcription updates
    private static let liveTranscriptionInterval: TimeInterval = 2.5

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

        // Snapshot current buffers on the processing queue
        let (buffersSnapshot, bufferCount): ([AVAudioPCMBuffer], Int) = audioProcessingQueueRef.sync {
            let count = self.audioBuffers.count
            // Only transcribe if we have new buffers since last live transcription
            guard count > self.lastLiveTranscribedBufferCount else { return ([], count) }
            return (Array(self.audioBuffers), count)
        }

        guard !buffersSnapshot.isEmpty, bufferCount > lastLiveTranscribedBufferCount else { return }

        isLiveTranscribing = true

        Task {
            do {
                let audioArray = try self.convertBuffersToFloatArray(buffersSnapshot)

                // Quick RMS check — skip if too quiet
                let rms = sqrt(audioArray.map { $0 * $0 }.reduce(0, +) / Float(max(audioArray.count, 1)))
                guard rms > 0.001 else {
                    await MainActor.run { self.isLiveTranscribing = false }
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
                guard !text.isEmpty, !hallucinations.contains(text.lowercased()) else {
                    await MainActor.run { self.isLiveTranscribing = false }
                    return
                }

                await MainActor.run {
                    self.liveTranscriptAccumulated = text
                    self.lastLiveTranscribedBufferCount = bufferCount
                    self.isLiveTranscribing = false

                    // Post live transcription update
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LiveTranscriptionUpdate"),
                        object: nil,
                        userInfo: ["text": text]
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
        debugLog("🛑 Ending streaming transcription")
        debugLog("📊 Total buffers accumulated: \(audioBuffers.count)")
        os_log("🛑 endStreamingTranscription: buffers=%d whisperKit=%{public}@", log: wLog, type: .info, audioBuffers.count, whisperKitRef == nil ? "nil" : "loaded")

        guard let whisperKit = whisperKitRef else {
            os_log("❌ whisperKit nil at endStreaming", log: wLog, type: .error)
            isProcessing = false
            completion(.failure(.modelNotLoaded))
            return
        }

        guard !audioBuffers.isEmpty else {
            os_log("❌ audioBuffers empty at endStreaming", log: wLog, type: .error)
            isProcessing = false
            completion(.failure(.noAudioData))
            return
        }

        // Synchronize with audioProcessingQueue to safely snapshot buffers
        let buffersSnapshot: [AVAudioPCMBuffer] = audioProcessingQueueRef.sync {
            let snapshot = self.audioBuffers
            self.audioBuffers = []
            return snapshot
        }

        Task {
            do {
                os_log("🔄 Task started: processing %d buffers", log: wLog, type: .info, buffersSnapshot.count)

                // Calculate total frames from all buffers
                let totalFrameCount = buffersSnapshot.reduce(0) { $0 + Int($1.frameLength) }
                let sampleRate = buffersSnapshot[0].format.sampleRate
                let audioDuration = Double(totalFrameCount) / sampleRate
                os_log("📊 Audio: %.2fs (%d frames, %.0fHz)", log: wLog, type: .info, audioDuration, totalFrameCount, sampleRate)

                // Convert all buffers to a single Float array
                let audioArray = try self.convertBuffersToFloatArray(buffersSnapshot)
                os_log("✅ Converted to %d samples", log: wLog, type: .info, audioArray.count)

                // Calculate RMS to verify audio is present
                let rms = sqrt(audioArray.map { $0 * $0 }.reduce(0, +) / Float(max(audioArray.count, 1)))
                os_log("🔊 RMS=%.6f (need >0.001)", log: wLog, type: .info, rms)

                // Start performance monitoring for transcription
                await MainActor.run {
                    PerformanceMonitor.shared.startTranscription(
                        engine: "WhisperKit",
                        model: self.loadedModelName ?? "unknown"
                    )
                }

                // Transcribe directly from audio array
                os_log("🎙️ Calling whisperKit.transcribe(audioArray:)...", log: wLog, type: .info)
                let transcriptionResult = try await self.transcribeWithCurrentSettings(audioArray: audioArray, whisperKit: whisperKit)
                os_log("📝 Transcription: '%@' (%d words)", log: wLog, type: .info, transcriptionResult.outputText, transcriptionResult.outputText.split(separator: " ").count)

                await MainActor.run {
                    // End performance monitoring with word count
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: transcriptionResult.outputText.split(separator: " ").count
                    )

                    self.currentText = transcriptionResult.outputText
                    self.isProcessing = false
                    os_log("✅ Final cleaned: '%@'", log: wLog, type: .info, transcriptionResult.outputText)
                    completion(.success(transcriptionResult))
                }
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
