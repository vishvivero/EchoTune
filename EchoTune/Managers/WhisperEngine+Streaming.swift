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
// Segment-wise streaming: each preview-tier tick transcribes ONLY the audio
// recorded since the previous tick (instead of re-transcribing the whole
// recording), and appends the result to liveSegmentTranscripts. On stop, only
// the final tail is transcribed and the cached segments are joined. This makes
// end-to-end latency O(tail) instead of O(entire recording).

extension WhisperEngine {

    /// The preview tier owns the interval; `.classic` preserves the previous
    /// four-second behavior as an immediate rollback path.

    func startStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) {
        // Abandon any prior stop/finalization work before opening a new
        // session. The token check below is the second line of defense for
        // decoders that do not observe cancellation immediately.
        cancelStreamingWorkForNewSession()

        // A new live session resets the language pin so detection starts
        // fresh — regardless of what a previous session pinned.
        resetSessionLanguage()

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
        liveAgreementWords = []
        liveWindowTranscript = ""
        liveWindowAgreementWords = []
        agreementEngine.reset()

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

    /// Live preview ticks detect language only on the first tick of the
    /// session; afterwards the pinned language is reused.
    var liveTickDetectLanguage: Bool { sessionDetectedLanguage == nil }

    /// The final tail re-detects when translate-to-English is on so the
    /// translation pass gets the true language, even if live ticks were
    /// pinned to a different language.
    var finalTailDetectLanguage: Bool {
        sessionDetectedLanguage == nil || AppSettings.shared.translateToEnglish
    }

    private func startLiveTranscriptionTimer() {
        stopLiveTranscriptionTimer()
        DispatchQueue.main.async { [weak self] in
            self?.liveTranscriptionTimer = Timer.scheduledTimer(withTimeInterval: AppSettings.shared.previewTier.interval, repeats: true) { [weak self] _ in
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

    /// Cancels work owned by the previous recording before a new session is
    /// opened. The session token prevents late decoder completions from
    /// mutating the new recording.
    func cancelStreamingWorkForNewSession() {
        currentTickTask?.cancel()
        streamingTask?.cancel()
        streamingSessionID = UUID()
    }

    /// Selects a bounded suffix without copying PCM data. Audio tap buffers
    /// are small enough that retaining the first buffer beyond the boundary is
    /// preferable to partial PCM copying and keeps channel formats intact.
    nonisolated private static func trailingBuffers(
        _ buffers: [AVAudioPCMBuffer],
        maximumSeconds: TimeInterval
    ) -> [AVAudioPCMBuffer] {
        guard let first = buffers.first, first.format.sampleRate > 0 else { return buffers }
        let maximumFrames = AVAudioFrameCount(maximumSeconds * first.format.sampleRate)
        var selected: [AVAudioPCMBuffer] = []
        var frameCount: AVAudioFrameCount = 0
        for buffer in buffers.reversed() {
            guard frameCount < maximumFrames else { break }
            selected.append(buffer)
            frameCount += buffer.frameLength
        }
        return selected.reversed()
    }

    /// Removes the longest word overlap between consecutive rolling windows.
    /// If decoding rewrites the overlap completely, retaining the new text is
    /// safer than dropping speech; the agreement layer can keep it pending.
    nonisolated private static func deltaText(previous: String, current: String) -> String {
        let previousWords = previous.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let currentWords = current.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !currentWords.isEmpty, !previousWords.isEmpty else { return current }
        let limit = min(previousWords.count, currentWords.count)
        for overlap in stride(from: limit, through: 1, by: -1) {
            let previousSuffix = previousWords.suffix(overlap).map(normalizedWord)
            let currentPrefix = currentWords.prefix(overlap).map(normalizedWord)
            if previousSuffix == currentPrefix {
                return currentWords.dropFirst(overlap).joined(separator: " ")
            }
        }
        return current
    }

    nonisolated private static func deltaWords(
        previous: [AgreementWord],
        current: [AgreementWord]
    ) -> [AgreementWord] {
        guard !current.isEmpty, !previous.isEmpty else { return current }
        let limit = min(previous.count, current.count)
        for overlap in stride(from: limit, through: 1, by: -1) {
            let previousSuffix = previous.suffix(overlap).map { normalizedWord($0.text) }
            let currentPrefix = current.prefix(overlap).map { normalizedWord($0.text) }
            if previousSuffix == currentPrefix {
                return Array(current.dropFirst(overlap))
            }
        }
        return current
    }

    nonisolated private static func normalizedWord(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
    }

    private func processLiveTranscriptionChunk() {
        guard !isLiveTranscribing else { return }
        guard let whisperKit = whisperKitRef else { return }

        // Classic retains the exact delta behavior. Faster tiers use a
        // bounded rolling window; the snapshot copies buffer references only,
        // so work does not grow with the recording length.
        let tier = AppSettings.shared.previewTier
        let (buffersSnapshot, bufferCount): ([AVAudioPCMBuffer], Int) = audioProcessingQueueRef.sync {
            let count = self.audioBuffers.count
            guard count > self.lastLiveTranscribedBufferCount else { return ([], count) }
            let allBuffers = Array(self.audioBuffers)
            if tier == .classic {
                return (Array(allBuffers[self.lastLiveTranscribedBufferCount...]), count)
            }
            return (Self.trailingBuffers(allBuffers, maximumSeconds: 5.0), count)
        }

        guard !buffersSnapshot.isEmpty, bufferCount > lastLiveTranscribedBufferCount else { return }

        isLiveTranscribing = true
        let sessionID = streamingSessionID

        let tickTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioArray = try self.convertBuffersToFloatArray(buffersSnapshot)

                // Quick RMS check — skip if too quiet
                let rms = sqrt(audioArray.map { $0 * $0 }.reduce(0, +) / Float(max(audioArray.count, 1)))
                guard rms > 0.001 else {
                    await MainActor.run {
                        guard self.streamingSessionID == sessionID else { return }
                        self.isLiveTranscribing = false
                        self.lastLiveTranscribedBufferCount = bufferCount
                    }
                    return
                }

                guard let decodeAudio = await self.audioForDecode(audioArray, context: "live tick") else {
                    await MainActor.run {
                        guard self.streamingSessionID == sessionID else { return }
                        self.isLiveTranscribing = false
                        self.lastLiveTranscribedBufferCount = bufferCount
                    }
                    return
                }

                guard self.streamingSessionID == sessionID, !Task.isCancelled else { return }
                let result = try await self.transcribeWithCurrentSettings(
                    audioArray: decodeAudio,
                    whisperKit: whisperKit,
                    detectLanguage: self.liveTickDetectLanguage,
                    mode: .live
                )
                let text = result.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                let agreementWords = result.agreementWords

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
                    guard self.streamingSessionID == sessionID else { return }
                    self.lastLiveTranscribedBufferCount = bufferCount
                    self.isLiveTranscribing = false

                    guard !text.isEmpty, !hallucinations.contains(text.lowercased()) else { return }

                    let newText = tier == .classic
                        ? text
                        : Self.deltaText(previous: self.liveWindowTranscript, current: text)
                    let newAgreementWords = agreementWords.map {
                        tier == .classic
                            ? $0
                            : Self.deltaWords(previous: self.liveWindowAgreementWords, current: $0)
                    }
                    self.liveWindowTranscript = text
                    if let agreementWords, !agreementWords.isEmpty {
                        self.liveWindowAgreementWords = agreementWords
                    }
                    guard !newText.isEmpty else { return }
                    self.liveSegmentTranscripts.append(newText)
                    self.liveTranscriptAccumulated = self.liveSegmentTranscripts.joined(separator: " ")

                    let notificationText: String
                    let notificationPending: String
                    if let agreementWords, !agreementWords.isEmpty {
                        self.liveAgreementWords.append(contentsOf: newAgreementWords ?? [])
                        let update = self.agreementEngine.ingest(self.liveAgreementWords)
                        notificationText = update.confirmed.joined(separator: " ")
                        notificationPending = update.hypothesis.joined(separator: " ")
                    } else {
                        notificationText = self.liveSegmentTranscripts.dropLast().joined(separator: " ")
                        notificationPending = newText
                    }

                    NotificationCenter.default.post(
                        name: NSNotification.Name("LiveTranscriptionUpdate"),
                        object: nil,
                        userInfo: ["text": notificationText, "pending": notificationPending]
                    )
                }
            } catch is CancellationError {
                // Stop deliberately cancels an in-flight tick. Its buffers
                // remain in the tail snapshot for the final decode.
                await MainActor.run {
                    guard self.streamingSessionID == sessionID else { return }
                    self.isLiveTranscribing = false
                }
            } catch {
                await MainActor.run {
                    guard self.streamingSessionID == sessionID else { return }
                    self.isLiveTranscribing = false
                    debugLog("⚠️ Live transcription chunk failed: \(error.localizedDescription)")
                }
            }
        }
        currentTickTask = tickTask
    }

    func endStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) {
        stopLiveTranscriptionTimer()
        debugLog("🛑 Ending streaming transcription (segment-wise)")

        guard let whisperKit = whisperKitRef else {
            os_log("❌ whisperKit nil at endStreaming", log: wLog, type: .error)
            isProcessing = false
            completion(.failure(.modelNotLoaded))
            return
        }

        let sessionID = streamingSessionID
        let tickTask = currentTickTask
        tickTask?.cancel()

        // Await the actual tick task instead of polling a Boolean with a fixed
        // deadline. Cancellation makes the normal path immediate; the await
        // also provides the ordering needed before snapshotting the tail.
        streamingTask?.cancel()
        streamingTask = Task { [weak self, tickTask] in
            if let tickTask {
                os_log("⏳ Cancelling in-flight live tick before final tail", log: wLog, type: .info)
                await tickTask.value
            }
            guard !Task.isCancelled, let self else { return }
            guard self.streamingSessionID == sessionID else {
                os_log("↩️ Abandoning stale streaming finalization", log: wLog, type: .info)
                return
            }
            let settleStarted = Date()
            await self.finalizeStreaming(
                whisperKit: whisperKit,
                sessionID: sessionID,
                completion: completion
            )
            os_log("✅ Streaming settle finished in %.3fs", log: wLog, type: .info, -settleStarted.timeIntervalSinceNow)
        }
    }

    /// Runs after any in-flight live tick has settled: snapshots the tail and
    /// decodes it, then joins committed segments + tail into the final result.
    private func finalizeStreaming(whisperKit: WhisperKit,
                                   sessionID: UUID,
                                   completion: @escaping (Result<WhisperTranscriptionResult, WhisperError>) -> Void) async {
        guard streamingSessionID == sessionID, !Task.isCancelled else { return }
        os_log("🛑 endStreamingTranscription: buffers=%d committedSegments=%d whisperKit=%{public}@", log: wLog, type: .info,
               audioBuffers.count, liveSegmentTranscripts.count, whisperKitRef == nil ? "nil" : "loaded")

        // Synchronize with audioProcessingQueue to safely snapshot buffers.
        // Buffers already covered by committed live-tick segments are dropped;
        // only the tail recorded since the last committed tick is decoded.
        let (fullBuffers, tailBuffers): ([AVAudioPCMBuffer], [AVAudioPCMBuffer]) = audioProcessingQueueRef.sync {
            let full = Array(self.audioBuffers)
            // If no live segment was successfully committed, retain the
            // entire recording for final/batch decoding. A tick that produced
            // no text must never make speech disappear from the tail.
            let committed = self.liveSegmentTranscripts.isEmpty
                ? 0
                : self.lastLiveTranscribedBufferCount
            let tail = committed < full.count ? Array(full[committed...]) : []
            self.audioBuffers = []
            return (full, tail)
        }

        let committedSegments = liveSegmentTranscripts

        // A short agreement session is unreliable even when no tail remains.
        // Re-run the complete captured audio through the batch path before
        // committing, unless the session was empty.
        if !fullBuffers.isEmpty {
            _ = agreementEngine.finish()
            if agreementEngine.shouldUseBatchFallback {
                let fallbackStarted = Date()
                os_log("↩️ Agreement requested full-audio batch fallback", log: wLog, type: .info)
                if let batchText = try? await transcribeFullAudio(
                    buffers: fullBuffers,
                    whisperKit: whisperKit,
                    sessionID: sessionID
                ) {
                    os_log("✅ Agreement batch fallback finished in %.3fs", log: wLog, type: .info, -fallbackStarted.timeIntervalSinceNow)
                    guard !Task.isCancelled, streamingSessionID == sessionID else { return }
                    deliverFinalResult(segments: [], tailText: batchText, completion: completion)
                    return
                }
                os_log("⚠️ Agreement batch fallback failed; retaining normal tail result", log: wLog, type: .error)
            }
        }

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

                guard !Task.isCancelled, streamingSessionID == sessionID,
                      let decodeAudio = await self.audioForDecode(audioArray, context: "final tail") else {
                    guard !Task.isCancelled, streamingSessionID == sessionID else { return }
                    await MainActor.run {
                        guard self.streamingSessionID == sessionID else { return }
                        self.isProcessing = false
                        if committedSegments.isEmpty {
                            completion(.failure(.noAudioData))
                        } else {
                            self.deliverFinalResult(segments: committedSegments, tailText: nil, completion: completion)
                        }
                    }
                    return
                }

                // Start performance monitoring for transcription
                await MainActor.run {
                    PerformanceMonitor.shared.startTranscription(
                        engine: "WhisperKit",
                        model: self.loadedModelName ?? "unknown"
                    )
                }

                // Transcribe the tail (or short final) segment directly
                os_log("🎙️ Calling whisperKit.transcribe(audioArray:) for final tail...", log: wLog, type: .info)
                let tailResult = try await self.transcribeWithCurrentSettings(
                    audioArray: decodeAudio,
                    whisperKit: whisperKit,
                    detectLanguage: self.finalTailDetectLanguage,
                    mode: .final
                )
                let tailText = tailResult.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                os_log("📝 Tail transcription: '%@'", log: wLog, type: .info, tailText)

                await MainActor.run {
                    PerformanceMonitor.shared.endTranscription(
                        wordCount: tailResult.outputText.split(separator: " ").count
                    )
                }

                guard !Task.isCancelled, streamingSessionID == sessionID else { return }
                if agreementEngine.shouldUseBatchFallback,
                   let batchText = try? await transcribeFullAudio(
                       buffers: fullBuffers,
                       whisperKit: whisperKit,
                       sessionID: sessionID
                   ) {
                    os_log("✅ Agreement batch fallback replaced tail result", log: wLog, type: .info)
                    deliverFinalResult(segments: [], tailText: batchText, completion: completion)
                } else {
                    deliverFinalResult(segments: committedSegments, tailText: tailText.isEmpty ? nil : tailText,
                                       completion: completion)
                }
        } catch is CancellationError {
            os_log("↩️ Final streaming settle cancelled", log: wLog, type: .info)
        } catch {
            os_log("❌ Transcription Task FAILED: %{public}@", log: wLog, type: .error, "\(error)")
            guard streamingSessionID == sessionID else { return }
            await MainActor.run {
                guard self.streamingSessionID == sessionID else { return }
                self.isProcessing = false

                debugLog("❌ Streaming transcription failed: \(error)")
                completion(.failure(.transcriptionFailed(error)))
            }
        }
    }

    private func transcribeFullAudio(
        buffers: [AVAudioPCMBuffer],
        whisperKit: WhisperKit,
        sessionID: UUID
    ) async throws -> String {
        guard !buffers.isEmpty, !Task.isCancelled, streamingSessionID == sessionID else {
            throw WhisperError.noAudioData
        }
        let samples = try convertBuffersToFloatArray(buffers)
        guard let decodeAudio = await audioForDecode(samples, context: "agreement batch fallback") else {
            throw WhisperError.noAudioData
        }
        let result = try await transcribeWithCurrentSettings(
            audioArray: decodeAudio,
            whisperKit: whisperKit,
            detectLanguage: finalTailDetectLanguage,
            mode: .final
        )
        return result.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
