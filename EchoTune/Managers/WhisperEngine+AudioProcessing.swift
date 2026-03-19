//
//  WhisperEngine+AudioProcessing.swift
//  EchoTune
//
//  Audio conversion and processing helpers for WhisperEngine.
//  Handles buffer merging, format conversion, and WAV export.
//
//  Created by Vishnu Raj on 26/10/2025.
//

import Foundation
import AVFoundation
import WhisperKit
import os.log

// MARK: - Audio Processing Helpers

extension WhisperEngine {

    func convertAudioDataToBuffer(_ audioData: Data) throws -> AVAudioPCMBuffer {
        // Read audio data from CAF/WAV format into a buffer
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_temp_\(UUID().uuidString).caf")

        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let audioFile = try AVAudioFile(forReading: tempURL)
        let format = audioFile.processingFormat

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw WhisperError.audioFormatError
        }

        try audioFile.read(into: buffer)
        buffer.frameLength = AVAudioFrameCount(audioFile.length)

        return buffer
    }

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

    func convertBufferToFloatArray(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        // Convert a single buffer to Float array for WhisperKit
        // Uses file-based resampling for reliability with any buffer size
        return try convertBuffersToFloatArray([buffer])
    }

    func convertBuffersToFloatArray(_ buffers: [AVAudioPCMBuffer]) throws -> [Float] {
        guard !buffers.isEmpty else {
            throw WhisperError.noAudioData
        }

        let inputFormat = buffers[0].format
        let targetSampleRate: Double = 16000

        os_log("🔄 convertBuffers: %d buffers, format=%.0fHz %dch %{public}@",
               log: wLog, type: .info, buffers.count, inputFormat.sampleRate, inputFormat.channelCount,
               inputFormat.commonFormat == .pcmFormatFloat32 ? "Float32" : inputFormat.commonFormat == .pcmFormatInt16 ? "Int16" : "other")

        // If already 16kHz mono Float32, just extract float data directly
        if inputFormat.sampleRate == targetSampleRate && inputFormat.channelCount == 1
            && inputFormat.commonFormat == .pcmFormatFloat32 {
            var result: [Float] = []
            for buffer in buffers {
                guard let channelData = buffer.floatChannelData else {
                    throw WhisperError.audioFormatError
                }
                let frameCount = Int(buffer.frameLength)
                result.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameCount))
            }
            os_log("✅ Already 16kHz mono Float32, %d samples", log: wLog, type: .info, result.count)
            return result
        }

        // Step 1: Merge all input buffers into one contiguous buffer
        let totalInputFrames = buffers.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard totalInputFrames > 0 else { throw WhisperError.noAudioData }

        guard let mergedInput = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: totalInputFrames) else {
            throw WhisperError.audioFormatError
        }

        var writeOffset: AVAudioFrameCount = 0
        for buffer in buffers {
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { continue }
            for channel in 0..<Int(inputFormat.channelCount) {
                if let src = buffer.floatChannelData?[channel],
                   let dst = mergedInput.floatChannelData?[channel] {
                    memcpy(dst.advanced(by: Int(writeOffset)), src, frameCount * MemoryLayout<Float>.size)
                }
            }
            writeOffset += buffer.frameLength
        }
        mergedInput.frameLength = totalInputFrames

        let inputDuration = Double(totalInputFrames) / inputFormat.sampleRate
        os_log("📦 Merged: %d frames (%.1fs at %.0fHz)",
               log: wLog, type: .info, totalInputFrames, inputDuration, inputFormat.sampleRate)

        // Step 2: Convert directly with AVAudioConverter (no temp file -- avoids format issues)
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            os_log("❌ Failed to create converter from %{public}@ to 16kHz", log: wLog, type: .error, "\(inputFormat)")
            throw WhisperError.audioFormatError
        }

        // Calculate output capacity generously
        let outputFrameCapacity = AVAudioFrameCount(ceil(inputDuration * targetSampleRate)) + 1000

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            throw WhisperError.audioFormatError
        }

        var inputConsumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return mergedInput
        }

        var convError: NSError?
        let status = converter.convert(to: outputBuffer, error: &convError, withInputFrom: inputBlock)

        os_log("🔧 Convert: status=%d outFrames=%d capacity=%d err=%{public}@",
               log: wLog, type: .info, status.rawValue, outputBuffer.frameLength, outputFrameCapacity,
               convError?.localizedDescription ?? "none")

        // AVAudioConverter sometimes returns .inputRanDry with valid data in the buffer
        if outputBuffer.frameLength == 0 {
            os_log("⚠️ frameLength=0, checking if data exists...", log: wLog, type: .info)
            // Try estimating the output size
            let estimated = AVAudioFrameCount(ceil(inputDuration * targetSampleRate))
            if estimated > 0 && (status == .haveData || status == .inputRanDry) {
                outputBuffer.frameLength = estimated
                os_log("⚠️ Set frameLength to estimated %d", log: wLog, type: .info, estimated)
            }
        }

        guard outputBuffer.frameLength > 0, let channelData = outputBuffer.floatChannelData else {
            os_log("❌ Conversion produced 0 frames, status=%d", log: wLog, type: .error, status.rawValue)
            throw WhisperError.noAudioData
        }

        let floatArray = Array(UnsafeBufferPointer(start: channelData[0], count: Int(outputBuffer.frameLength)))

        // Verify audio content
        let rms = sqrt(floatArray.map { $0 * $0 }.reduce(0, +) / Float(max(floatArray.count, 1)))
        os_log("✅ Output: %d samples (%.1fs), RMS=%.6f", log: wLog, type: .info,
               floatArray.count, Double(floatArray.count) / targetSampleRate, rms)

        return floatArray
    }

    func mergeBuffers(_ buffers: [AVAudioPCMBuffer]) throws -> AVAudioPCMBuffer {
        guard !buffers.isEmpty else {
            throw WhisperError.noAudioData
        }

        // Pre-calculate total size once
        let format = buffers[0].format
        let totalFrames = buffers.reduce(0) { $0 + AVAudioFrameCount($1.frameLength) }

        guard let mergedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: totalFrames
        ) else {
            throw WhisperError.audioFormatError
        }

        // Use UnsafeMutableBufferPointer for faster memory operations
        let channelCount = Int(format.channelCount)
        let floatSize = MemoryLayout<Float>.stride

        var currentFrame: AVAudioFramePosition = 0
        for buffer in buffers {
            let frameLength = Int(buffer.frameLength)
            let byteCount = frameLength * floatSize

            // Process all channels at once
            for channel in 0..<channelCount {
                if let src = buffer.floatChannelData?[channel],
                   let dst = mergedBuffer.floatChannelData?[channel] {
                    // Single memcpy per buffer per channel (more efficient)
                    memcpy(dst.advanced(by: Int(currentFrame)), src, byteCount)
                }
            }

            currentFrame += AVAudioFramePosition(frameLength)
        }

        mergedBuffer.frameLength = totalFrames
        return mergedBuffer
    }

    func mergeBuffersToWAV(_ buffers: [AVAudioPCMBuffer]) throws -> Data {
        guard !buffers.isEmpty else {
            throw WhisperError.noAudioData
        }

        // Get format from first buffer
        let format = buffers[0].format

        // Calculate total frame count
        let totalFrames = buffers.reduce(0) { $0 + AVAudioFrameCount($1.frameLength) }

        // Create merged buffer
        guard let mergedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: totalFrames
        ) else {
            throw WhisperError.audioFormatError
        }

        // Copy all buffers into merged buffer
        var currentFrame: AVAudioFramePosition = 0
        for buffer in buffers {
            let frameLength = buffer.frameLength

            for channel in 0..<Int(format.channelCount) {
                if let src = buffer.floatChannelData?[channel],
                   let dst = mergedBuffer.floatChannelData?[channel] {
                    memcpy(dst.advanced(by: Int(currentFrame)), src, Int(frameLength) * MemoryLayout<Float>.size)
                }
            }

            currentFrame += AVAudioFramePosition(frameLength)
        }

        mergedBuffer.frameLength = totalFrames

        // Convert to WAV data
        return try convertToWAV(mergedBuffer)
    }

    func convertToWAV(_ buffer: AVAudioPCMBuffer) throws -> Data {
        // For Whisper, we need 16kHz mono PCM Float32
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        debugLog("🔄 Converting audio for Whisper:")
        debugLog("   Input: \(buffer.format.sampleRate)Hz, \(buffer.format.channelCount) ch, \(buffer.frameLength) frames")
        debugLog("   Target: \(targetFormat.sampleRate)Hz, \(targetFormat.channelCount) ch")

        // Create converter
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            debugLog("❌ Failed to create audio converter")
            throw WhisperError.audioFormatError
        }

        // Calculate output frame capacity
        let frameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate))

        debugLog("   Calculated output capacity: \(frameCapacity) frames")

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCapacity
        ) else {
            debugLog("❌ Failed to create output buffer")
            throw WhisperError.audioFormatError
        }

        // Perform conversion
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

        if let error = error {
            debugLog("❌ Conversion error: \(error)")
            throw WhisperError.transcriptionFailed(error)
        }

        if status != .haveData {
            debugLog("⚠️ Conversion status: \(status)")
        }

        // Set the actual frame length (converter doesn't set this automatically)
        convertedBuffer.frameLength = frameCapacity

        debugLog("✅ Converted buffer: \(convertedBuffer.frameLength) frames")

        // Check if buffer has actual audio data
        if let channelData = convertedBuffer.floatChannelData {
            let samples = UnsafeBufferPointer(start: channelData[0], count: Int(convertedBuffer.frameLength))
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(convertedBuffer.frameLength))
            debugLog("   RMS level: \(rms) (should be > 0.001 for speech)")

            if rms < 0.001 {
                debugLog("⚠️ WARNING: Audio level too low - may not contain speech!")
            }
        }

        // Write to WAV file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_audio_\(UUID().uuidString).wav")

        let audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: targetFormat.settings,
            commonFormat: targetFormat.commonFormat,
            interleaved: targetFormat.isInterleaved
        )

        try audioFile.write(from: convertedBuffer)

        let data = try Data(contentsOf: tempURL)
        debugLog("✅ WAV file created: \(data.count) bytes at \(tempURL.lastPathComponent)")

        try? FileManager.default.removeItem(at: tempURL)

        return data
    }
}
