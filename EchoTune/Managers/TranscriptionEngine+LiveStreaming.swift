//
//  TranscriptionEngine+LiveStreaming.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import Speech
import AVFoundation

// MARK: - Live Streaming Transcription

extension TranscriptionEngine {

    // MARK: - Start Live Transcription

    func startLiveTranscription(audioFormat: AVAudioFormat, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        debugLog("🎤 Starting live transcription (with auto-restart for long recordings)...")

        // Prevent multiple simultaneous tasks
        guard !isTranscribing else {
            debugLog("⚠️ Already transcribing, ignoring start request")
            return
        }

        // Cancel any existing task before starting new one
        if let existingTask = recognitionTask {
            debugLog("🛑 Cancelling existing recognition task")
            existingTask.cancel()
        }
        recognitionTask = nil
        recognitionRequest = nil

        // Reset counters
        bufferCount = 0
        totalFrames = 0
        accumulatedTranscriptions = []
        currentSessionText = ""
        sessionRestartCount = 0
        lastSessionFrameCount = 0

        guard isAvailable else {
            completion(.failure(.unavailable))
            return
        }

        guard isPermissionGranted else {
            completion(.failure(.permissionDenied))
            return
        }

        isTranscribing = true
        isProcessing = true
        currentText = ""

        // Store for auto-restart
        liveInputFormat = audioFormat
        liveCompletion = completion

        // Create Int16 PCM format for Speech Recognition
        guard let int16Format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: audioFormat.sampleRate,
            channels: audioFormat.channelCount,
            interleaved: false
        ) else {
            debugLog("❌ Failed to create Int16 format")
            completion(.failure(.audioFormatError))
            return
        }

        targetFormat = int16Format

        // Create converter from Float32 to Int16
        guard let converter = AVAudioConverter(from: audioFormat, to: int16Format) else {
            debugLog("❌ Failed to create audio converter")
            completion(.failure(.audioFormatError))
            return
        }

        audioConverter = converter

        // Start the first recognition session
        startRecognitionSession()

        debugLog("✓ Live recognition task started (auto-restart enabled)")
    }

    // MARK: - Recognition Session Management

    /// Starts or restarts a recognition session.
    /// Called initially and when a session times out for long recordings.
    func startRecognitionSession() {
        // Cancel previous session if any
        recognitionTask?.cancel()
        recognitionRequest = nil
        lastSessionFrameCount = 0

        // Create recognition request for live audio
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        guard let speechRecognizer = self.speechRecognizer else {
            debugLog("❌ Speech recognizer not available")
            isProcessing = false
            liveCompletion?(.failure(.unavailable))
            return
        }

        let sessionIndex = sessionRestartCount
        debugLog("🔄 Starting recognition session #\(sessionIndex)")

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }

            // If we're no longer transcribing (user stopped), still update partial text
            // but don't restart sessions. The endLiveTranscription timeout will handle completion.
            let isActive = self.isTranscribing

            if let error = error {
                let nsError = error as NSError
                debugLog("⚠️ Recognition session #\(sessionIndex) error: \(error.localizedDescription) (code: \(nsError.code))")

                // Only auto-restart if we're still actively transcribing
                let recoverableCodes = [203, 209, 216, 1110]
                if recoverableCodes.contains(nsError.code) && isActive {
                    // Save current partial text and restart
                    if !self.currentSessionText.isEmpty {
                        self.accumulatedTranscriptions.append(self.currentSessionText)
                        debugLog("📝 Saved session #\(sessionIndex) text: \(self.currentSessionText)")
                    }
                    self.currentSessionText = ""
                    self.sessionRestartCount += 1

                    debugLog("🔄 Auto-restarting recognition (session \(self.sessionRestartCount))...")
                    self.startRecognitionSession()
                    return
                }

                // Non-recoverable error or we're stopping — save what we have
                if !self.currentSessionText.isEmpty {
                    self.accumulatedTranscriptions.append(self.currentSessionText)
                    self.currentSessionText = ""
                }

                // Only fire completion if we're still the active handler (isActive)
                if isActive {
                    if !self.accumulatedTranscriptions.isEmpty {
                        let merged = AudioChunker.mergeTranscriptions(self.accumulatedTranscriptions)
                        let processedText = self.processText(merged)
                        self.isTranscribing = false
                        self.isProcessing = false
                        self.liveCompletion?(.success(processedText))
                    } else {
                        self.isTranscribing = false
                        self.isProcessing = false
                        self.liveCompletion?(.failure(.recognitionError(error)))
                    }
                }
                return
            }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                self.currentSessionText = transcription

                // Show accumulated + current text
                let allParts = self.accumulatedTranscriptions + [transcription]
                let displayText = AudioChunker.mergeTranscriptions(allParts)
                self.currentText = displayText

                if result.isFinal {
                    debugLog("✅ Session #\(sessionIndex) final: \(transcription)")
                    self.accumulatedTranscriptions.append(transcription)
                    self.currentSessionText = ""

                    // If we're still recording, auto-restart for continued transcription
                    if self.isTranscribing {
                        self.sessionRestartCount += 1
                        debugLog("🔄 Session ended, auto-restarting (session \(self.sessionRestartCount))...")
                        self.startRecognitionSession()
                    }
                }
            }
        }
    }

    // MARK: - Append Audio Buffer

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Process buffer on background queue to avoid blocking UI
        audioProcessingQueue.async { [weak self] in
            guard let self = self else { return }

            // Convert Float32 buffer to Int16 before sending to Speech Recognition
            guard let converter = self.audioConverter,
                  let targetFormat = self.targetFormat else {
                return
            }

            // Track buffer stats
            self.bufferCount += 1
            self.totalFrames += buffer.frameLength
            self.lastSessionFrameCount += buffer.frameLength

            // Log every 100th buffer to avoid spam
            if self.bufferCount % 100 == 1 || self.bufferCount <= 5 {
                let totalSec = Double(self.totalFrames) / buffer.format.sampleRate
                let sessionSec = Double(self.lastSessionFrameCount) / buffer.format.sampleRate
                debugLog("🎵 Buffer #\(self.bufferCount): total=\(String(format: "%.1f", totalSec))s, session=\(String(format: "%.1f", sessionSec))s")
            }

            // Create output buffer for converted audio
            let frameCapacity = buffer.frameLength
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCapacity
            ) else {
                debugLog("❌ Failed to create converted buffer")
                return
            }

            // Convert the buffer
            var error: NSError?
            var inputConsumed = false
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                if inputConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputConsumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            // Log detailed conversion info for first few buffers
            if self.bufferCount <= 3 {
                debugLog("   Conversion status: \(status)")
                debugLog("   Converted buffer format: \(convertedBuffer.format)")
            }

            if status == .error {
                debugLog("❌ Buffer conversion error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            if status != .haveData {
                return
            }

            // CRITICAL: Set the frame length on the converted buffer
            convertedBuffer.frameLength = buffer.frameLength

            // Verify the buffer has valid data
            if convertedBuffer.frameLength == 0 {
                return
            }

            // Append converted Int16 buffer to recognition request
            self.recognitionRequest?.append(convertedBuffer)
        }
    }

    // MARK: - End Live Transcription

    func endLiveTranscription() {
        debugLog("🛑 Ending live transcription")
        debugLog("📊 Total buffers processed: \(bufferCount)")
        debugLog("📊 Total frames: \(totalFrames) (\(Double(totalFrames) / 48000.0) seconds)")
        debugLog("📊 Sessions used: \(sessionRestartCount + 1)")

        // End audio on current request
        recognitionRequest?.endAudio()
        audioConverter = nil
        targetFormat = nil

        // Capture everything we need BEFORE clearing state
        let existingAccumulated = accumulatedTranscriptions
        let existingCurrent = currentSessionText
        let existingCompletion = liveCompletion

        // Mark that we're stopping — the recognition task handler checks this
        // But DON'T nil the completion yet — the timeout block needs it
        isTranscribing = false
        liveInputFormat = nil

        // Use a flag to track if the recognition task's own handler fires the completion
        var completionFired = false

        // Give the recognition task a moment to finalize with isFinal result
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard !completionFired else { return }
            completionFired = true

            debugLog("⏱️ Recognition didn't finalize in time — returning accumulated text")

            var allParts = existingAccumulated
            if !existingCurrent.isEmpty {
                allParts.append(existingCurrent)
            }

            if !allParts.isEmpty {
                let merged = AudioChunker.mergeTranscriptions(allParts)
                let processedText = self.processText(merged)
                self.isProcessing = false
                existingCompletion?(.success(processedText))
            } else {
                // No text at all — return empty success rather than hanging forever
                self.isProcessing = false
                existingCompletion?(.success(""))
            }

            // Clean up the recognition task
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil
        }

        // Also hook into the recognition task's own completion to fire faster if possible
        // The existing recognitionTask handler in startRecognitionSession checks isTranscribing
        // and since we set it to false above, when the task handler fires with isFinal or error,
        // it will try to use liveCompletion. But we already captured it above.
        // So we need a different approach: override the completion in the task handler.

        // Clear liveCompletion so the session handler doesn't also fire it
        liveCompletion = nil
    }
}
