//
//  AudioManager+ChunkedStorage.swift
//  EchoTune
//
//  Chunked audio storage — manages growing audio buffer system
//  Split from AudioManager.swift
//

import Foundation
import AVFoundation

// MARK: - Chunked Audio Storage

extension AudioManager {

    /// Appends audio to the growing chunk-based buffer system.
    /// When the current chunk fills up, it's stored and a new chunk is allocated.
    func appendToChunkedStorage(_ buffer: AVAudioPCMBuffer) {
        guard var chunk = currentChunk else { return }

        let totalFrames = Int(buffer.frameLength)
        var sourceOffset = 0
        var remaining = totalFrames

        while remaining > 0 {
            let framesAvailable = Int(chunk.frameCapacity - currentChunkFrameOffset)

            if framesAvailable == 0 {
                // Current chunk is full — save it and allocate a new one
                chunk.frameLength = currentChunkFrameOffset
                audioChunks.append(chunk)

                // Memory cap: limit to ~600 chunks (~10 min at 30s/chunk = 300 chunks, but be generous)
                let maxChunks = 600
                if audioChunks.count > maxChunks {
                    audioChunks.removeFirst()
                    debugLog("⚠️ Audio buffer memory cap reached — dropped oldest chunk")
                }

                let newCapacity = AVAudioFrameCount(buffer.format.sampleRate * AudioManager.chunkDurationSeconds)
                guard let newChunk = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: newCapacity) else {
                    debugLog("⚠️ Failed to allocate new audio chunk — recording may be truncated")
                    return
                }
                currentChunk = newChunk
                chunk = newChunk
                currentChunkFrameOffset = 0

                let totalSeconds = Double(audioChunks.count) * AudioManager.chunkDurationSeconds
                debugLog("📦 Audio chunk \(audioChunks.count) stored (\(Int(totalSeconds))s total buffered)")
                continue
            }

            let copyCount = min(remaining, framesAvailable)

            // Copy audio data into current chunk
            for channel in 0..<Int(buffer.format.channelCount) {
                guard let inputData = buffer.floatChannelData?[channel],
                      let outputData = chunk.floatChannelData?[channel] else { break }
                memcpy(outputData.advanced(by: Int(currentChunkFrameOffset)),
                       inputData.advanced(by: sourceOffset),
                       copyCount * MemoryLayout<Float>.size)
            }

            currentChunkFrameOffset += AVAudioFrameCount(copyCount)
            chunk.frameLength = currentChunkFrameOffset
            sourceOffset += copyCount
            remaining -= copyCount
        }

        // Also update the legacy audioBuffer for backward compatibility
        if let audioBuffer = self.audioBuffer {
            let offset = Int(audioBuffer.frameLength)
            let legacyAvailable = Int(audioBuffer.frameCapacity - audioBuffer.frameLength)
            let legacyCopy = min(totalFrames, legacyAvailable)

            if legacyCopy > 0 {
                for channel in 0..<Int(buffer.format.channelCount) {
                    if let inputData = buffer.floatChannelData?[channel],
                       let outputData = audioBuffer.floatChannelData?[channel] {
                        memcpy(outputData.advanced(by: offset), inputData, legacyCopy * MemoryLayout<Float>.size)
                    }
                }
                audioBuffer.frameLength += AVAudioFrameCount(legacyCopy)
            }
        }
    }

    /// Merge all audio chunks (including current partial chunk) into a single buffer
    func mergeAllAudioChunks() -> AVAudioPCMBuffer? {
        // Finalize the current chunk
        var allChunks = audioChunks
        if let current = currentChunk, currentChunkFrameOffset > 0 {
            current.frameLength = currentChunkFrameOffset
            allChunks.append(current)
        }

        guard !allChunks.isEmpty else {
            // Fallback to legacy buffer
            return audioBuffer
        }

        // Calculate total frames
        let totalFrames = allChunks.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard totalFrames > 0 else { return audioBuffer }

        let format = allChunks[0].format
        guard let merged = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            debugLog("⚠️ Failed to allocate merged buffer (\(totalFrames) frames) — falling back to legacy buffer")
            return audioBuffer
        }

        var writeOffset: AVAudioFrameCount = 0
        for chunk in allChunks {
            let frameCount = Int(chunk.frameLength)
            for channel in 0..<Int(format.channelCount) {
                if let src = chunk.floatChannelData?[channel],
                   let dst = merged.floatChannelData?[channel] {
                    memcpy(dst.advanced(by: Int(writeOffset)), src, frameCount * MemoryLayout<Float>.size)
                }
            }
            writeOffset += chunk.frameLength
        }
        merged.frameLength = totalFrames

        return merged
    }
}
