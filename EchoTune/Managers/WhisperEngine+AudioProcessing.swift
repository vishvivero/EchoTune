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

    // MARK: - Transcription With App Settings

    func transcribeWithCurrentSettings(audioArray: [Float], whisperKit: WhisperKit) async throws -> WhisperTranscriptionResult {
        let settings = AppSettings.shared
        let preferredLanguage = settings.preferredLanguage.components(separatedBy: "-").first

        let transcriptionOptions = DecodingOptions(
            task: .transcribe,
            language: settings.autoDetectLanguage ? nil : preferredLanguage,
            detectLanguage: settings.autoDetectLanguage || settings.translateToEnglish
        )
        let transcriptionPass = try await whisperKit.transcribe(audioArray: audioArray, decodeOptions: transcriptionOptions)
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
                language: settings.autoDetectLanguage ? nil : preferredLanguage,
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
                detectedLanguage: detectedLanguage
            )
        }

        return WhisperTranscriptionResult(
            outputText: originalText,
            originalText: originalText,
            translatedText: nil,
            detectedLanguage: detectedLanguage
        )
    }
}
