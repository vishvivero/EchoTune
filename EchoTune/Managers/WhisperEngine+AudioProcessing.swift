//
//  WhisperEngine+AudioProcessing.swift
//  EchoTune
//
//  Turns captured audio (encoded file bytes or live PCM buffers) into the
//  16 kHz mono Float stream WhisperKit consumes. Conversion runs
//  incrementally — buffers are fed through the converter one at a time —
//  so long recordings never need a second full-size copy in memory.
//

import Foundation
import AVFoundation
import WhisperKit
import os.log

extension WhisperEngine {

    private static let whisperSampleRate: Double = 16_000

    private static var whisperFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: whisperSampleRate,
                      channels: 1,
                      interleaved: false)!
    }

    // MARK: - Decoding Encoded Audio

    /// Decodes encoded audio bytes (CAF/WAV/etc.) into a PCM buffer at the
    /// file's native processing format. AVAudioFile only reads from disk, so
    /// the bytes take a brief round-trip through the temp directory.
    func convertAudioDataToBuffer(_ audioData: Data) throws -> AVAudioPCMBuffer {
        let scratchURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("decode-\(UUID().uuidString).caf")
        try audioData.write(to: scratchURL)
        defer { try? FileManager.default.removeItem(at: scratchURL) }

        let file = try AVAudioFile(forReading: scratchURL)
        let frameCount = AVAudioFrameCount(file.length)

        guard frameCount > 0,
              let pcm = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            throw WhisperError.audioFormatError
        }

        try file.read(into: pcm)
        return pcm
    }

    // MARK: - PCM → Whisper Float Stream

    func convertBufferToFloatArray(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        try convertBuffersToFloatArray([buffer])
    }

    /// Concatenates PCM buffers and resamples to 16 kHz mono Float32.
    /// Buffers must share one format. Already-conformant input is copied out
    /// directly with no converter involved.
    func convertBuffersToFloatArray(_ buffers: [AVAudioPCMBuffer]) throws -> [Float] {
        let nonEmpty = buffers.filter { $0.frameLength > 0 }
        guard let first = nonEmpty.first else {
            throw WhisperError.noAudioData
        }

        let sourceFormat = first.format

        // Fast path: nothing to convert.
        if sourceFormat.sampleRate == Self.whisperSampleRate,
           sourceFormat.channelCount == 1,
           sourceFormat.commonFormat == .pcmFormatFloat32 {
            var samples: [Float] = []
            samples.reserveCapacity(nonEmpty.reduce(0) { $0 + Int($1.frameLength) })
            for pcm in nonEmpty {
                guard let mono = pcm.floatChannelData?[0] else { throw WhisperError.audioFormatError }
                samples.append(contentsOf: UnsafeBufferPointer(start: mono, count: Int(pcm.frameLength)))
            }
            return samples
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: Self.whisperFormat) else {
            os_log("Converter unavailable for %{public}@ → 16kHz mono", log: wLog, type: .error, "\(sourceFormat)")
            throw WhisperError.audioFormatError
        }

        // Incremental conversion: hand the converter one source buffer per
        // pull, draining output in fixed-size slabs until it reports the
        // stream is finished.
        var pending = nonEmpty[...]
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            guard let next = pending.first else {
                status.pointee = .endOfStream
                return nil
            }
            pending = pending.dropFirst()
            status.pointee = .haveData
            return next
        }

        let slabCapacity: AVAudioFrameCount = 32 * 1024
        var samples: [Float] = []

        conversionLoop: while true {
            guard let slab = AVAudioPCMBuffer(pcmFormat: Self.whisperFormat, frameCapacity: slabCapacity) else {
                throw WhisperError.audioFormatError
            }

            var conversionError: NSError?
            let status = converter.convert(to: slab, error: &conversionError, withInputFrom: inputBlock)

            if let conversionError {
                os_log("Resample failed: %{public}@", log: wLog, type: .error, conversionError.localizedDescription)
                throw WhisperError.transcriptionFailed(conversionError)
            }

            if slab.frameLength > 0, let mono = slab.floatChannelData?[0] {
                samples.append(contentsOf: UnsafeBufferPointer(start: mono, count: Int(slab.frameLength)))
            }

            switch status {
            case .endOfStream, .error:
                break conversionLoop
            case .inputRanDry where pending.isEmpty && slab.frameLength == 0:
                break conversionLoop
            default:
                continue
            }
        }

        guard !samples.isEmpty else {
            throw WhisperError.noAudioData
        }

        os_log("Resampled %d buffers → %d samples (%.1fs)", log: wLog, type: .info,
               nonEmpty.count, samples.count, Double(samples.count) / Self.whisperSampleRate)
        return samples
    }

    // MARK: - VAD Decode Window

    /// Returns individually trimmed speech regions. A VAD/model failure falls
    /// back to one untrimmed region so speech is never lost; clean silence
    /// returns nil and callers skip the decoder entirely.
    func audioSegmentsForDecode(_ samples: [Float], context: String) async -> [[Float]]? {
        guard !samples.isEmpty else { return nil }
        guard VADManager.shared.config.enabled else { return [samples] }

        do {
            let spans = try await VADManager.shared.speechSpans(in: samples, sampleRate: Self.whisperSampleRate)
            guard !spans.isEmpty else {
                debugLog("🎙️ VAD: no speech in \(context) — skipping decode")
                return nil
            }

            let segments = spans.compactMap { span in
                SilenceTrimmer.trim(
                    samples: samples,
                    spans: [span],
                    sampleRate: Self.whisperSampleRate,
                    padding: 0.05,
                    mergeGap: 0,
                    minimumLength: 0.5
                )
            }
            guard !segments.isEmpty else {
                debugLog("🎙️ VAD: speech window too short in \(context) — skipping decode")
                return nil
            }

            let originalDuration = Double(samples.count) / Self.whisperSampleRate
            let keptSamples = segments.reduce(0) { $0 + $1.count }
            let keptDuration = Double(keptSamples) / Self.whisperSampleRate
            if keptSamples < samples.count {
                debugLog("🎙️ VAD: trimmed \(context) from \(String(format: "%.2f", originalDuration))s to \(String(format: "%.2f", keptDuration))s in \(segments.count) segment(s)")
            }
            return segments
        } catch {
            if !didLogVADDecodeFailure {
                didLogVADDecodeFailure = true
                debugLog("⚠️ VAD decode preparation failed; decoding untrimmed audio: \(error.localizedDescription)")
            }
            return [samples]
        }
    }

    /// Live ticks use one decode window. Separate speech regions are flattened
    /// only for the preview path; final/batch transcription decodes each region
    /// independently via `audioSegmentsForDecode`.
    func audioForDecode(_ samples: [Float], context: String) async -> [Float]? {
        guard let segments = await audioSegmentsForDecode(samples, context: context) else { return nil }
        return segments.flatMap { $0 }
    }

    func mergeTranscriptionResults(_ results: [WhisperTranscriptionResult]) -> WhisperTranscriptionResult {
        let output = results.map(\.outputText).filter { !$0.isEmpty }.joined(separator: " ")
        let original = results.map(\.originalText).filter { !$0.isEmpty }.joined(separator: " ")
        let translatedValues = results.compactMap(\.translatedText).filter { !$0.isEmpty }
        return WhisperTranscriptionResult(
            outputText: output,
            originalText: original,
            translatedText: translatedValues.isEmpty ? nil : translatedValues.joined(separator: " "),
            detectedLanguage: results.compactMap(\.detectedLanguage).first
        )
    }

    // MARK: - Transcription With App Settings

    /// Whether a decode is for a live preview tick or a final/finished
    /// dictation. `live` skips the temperature-fallback chain; `final`
    /// reproduces the full WhisperKit defaults for accuracy.
    enum DecodeMode {
        case live
        case final
    }

    /// Pure factory — testable without a live model. Builds the options for
    /// one decode pass given a `mode` and whether to run language detection.
    /// `mode == .final` must reproduce WhisperKit's defaults so batch output
    /// stays byte-identical to 7.1.0.
    /// `promptTokens` is deliberately never set. WhisperKit 0.15.0 returns an
    /// EMPTY transcription for every decode when `promptTokens` is non-nil with
    /// the local CoreML Whisper models: the same audio transcribes correctly
    /// with no conditioning and returns "" with any prompt, however short.
    /// Sending the same terms as `prefixTokens` is no better — the decoder
    /// treats them as already-produced text, echoes them and drops real audio.
    /// Vocabulary is therefore applied to the finished text instead.
    func makeDecodingOptions(
        mode: DecodeMode,
        detectLanguage: Bool,
        language: String?,
        wordTimestamps: Bool? = nil
    ) -> DecodingOptions {
        DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureFallbackCount: mode == .live ? 0 : 5,
            detectLanguage: detectLanguage,
            skipSpecialTokens: false,
            wordTimestamps: wordTimestamps ?? (mode == .live)
        )
    }

    func transcribeWithCurrentSettings(
        audioArray: [Float],
        whisperKit: WhisperKit,
        detectLanguage: Bool? = nil,
        mode: DecodeMode = .final
    ) async throws -> WhisperTranscriptionResult {
        let settings = AppSettings.shared
        let preferredLanguage = settings.preferredLanguage.components(separatedBy: "-").first

        let shouldDetect = detectLanguage ?? (settings.autoDetectLanguage || settings.translateToEnglish)
        let languageForDecode = sessionDetectedLanguage ?? preferredLanguage

        // NOTE: no decoder-side vocabulary conditioning is passed here — see
        // makeDecodingOptions() for why. `settings.vocabularyBiasingEnabled`
        // now gates the post-hoc dictionary pass in the text pipeline.
        let transcriptionOptions = makeDecodingOptions(
            mode: mode,
            detectLanguage: shouldDetect,
            language: languageForDecode,
            // WhisperKit's word-timestamp alignment is enabled only for live
            // ticks; the final path retains its pre-Phase-7 defaults.
            wordTimestamps: mode == .live
        )
        let transcriptionPass = try await whisperKit.transcribe(audioArray: audioArray, decodeOptions: transcriptionOptions)
        let agreementWords: [AgreementWord]? = transcriptionOptions.wordTimestamps
            ? transcriptionPass.flatMap { result in
                result.allWords.map { AgreementWord(text: $0.word, confidence: $0.probability) }
            }
            : nil

        // Pin the detected language on the first decode of the session so
        // subsequent live ticks reuse it instead of re-detecting.
        if sessionDetectedLanguage == nil, let detected = transcriptionPass.first?.language, !detected.isEmpty {
            sessionDetectedLanguage = detected
        }

        let originalText = TranscriptionEngine.shared.processText(
            transcriptionPass
                .map { $0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        )
        let detectedLanguage = transcriptionPass.first?.language

        if settings.translateToEnglish, let detectedLanguage, !detectedLanguage.hasPrefix("en") {
            let translationOptions = DecodingOptions(
                task: .translate,
                language: preferredLanguage,
                detectLanguage: true
            )
            let translationPass = try await whisperKit.transcribe(audioArray: audioArray, decodeOptions: translationOptions)
            let translatedText = TranscriptionEngine.shared.processText(
                translationPass
                    .map { $0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            )

            return WhisperTranscriptionResult(
                outputText: translatedText,
                originalText: originalText,
                translatedText: translatedText,
                detectedLanguage: detectedLanguage,
                agreementWords: agreementWords
            )
        }

        return WhisperTranscriptionResult(
            outputText: originalText,
            originalText: originalText,
            translatedText: nil,
            detectedLanguage: detectedLanguage,
            agreementWords: agreementWords
        )
    }
}
