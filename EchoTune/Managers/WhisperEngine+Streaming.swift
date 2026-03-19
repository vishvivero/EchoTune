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

        debugLog("🎤 Starting streaming transcription...")
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        audioProcessingQueueRef.async { [weak self] in
            guard let self = self else { return }

            // Accumulate buffers for batch processing
            self.audioBuffers.append(buffer)

            // For now, we'll process when user stops recording
            // WhisperKit works better with complete audio rather than streaming
        }
    }

    func endStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) {
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
                os_log("📝 Transcription: '%{public}@' (%d words)", log: wLog, type: .info, transcriptionResult.outputText, transcriptionResult.outputText.split(separator: " ").count)

                await MainActor.run {
                    // End performance monitoring with word count
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: transcriptionResult.outputText.split(separator: " ").count
                    )

                    self.currentText = transcriptionResult.outputText
                    self.isProcessing = false
                    os_log("✅ Final cleaned: '%{public}@'", log: wLog, type: .info, transcriptionResult.outputText)
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
