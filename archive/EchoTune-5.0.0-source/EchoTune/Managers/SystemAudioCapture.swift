//
//  SystemAudioCapture.swift
//  EchoTune
//
//  Captures system audio output using ScreenCaptureKit (macOS 13+).
//  No meeting bots — records directly from system audio.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

@available(macOS 13.0, *)
class SystemAudioCapture: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var isCapturing = false
    @Published var audioLevel: Float = 0.0

    // MARK: - Callbacks
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // MARK: - Private
    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?
    private let audioEngine = AVAudioEngine()

    // Configuration
    private let sampleRate: Double = 16000  // 16kHz for Whisper compatibility
    private let channelCount: Int = 1       // Mono

    // MARK: - Permission Check

    static func hasPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    // MARK: - Start Capture

    /// Start capturing system audio (all audio output from the Mac).
    func startCapture() async throws {
        guard !isCapturing else {
            debugLog("⚠️ SystemAudioCapture: Already capturing")
            return
        }

        debugLog("🎤 SystemAudioCapture: Starting system audio capture...")

        // Get shareable content (all windows/displays)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            debugLog("❌ SystemAudioCapture: No displays found")
            throw SystemAudioCaptureError.noDisplayFound
        }

        // Create a content filter for the entire display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure stream — audio only, no video
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = Int(sampleRate)
        config.channelCount = channelCount
        config.excludesCurrentProcessAudio = true  // Don't capture EchoTune's own audio

        // Minimise video overhead (we only want audio)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 FPS minimum
        config.showsCursor = false

        // Create the stream
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        // Create output handler
        let output = AudioStreamOutput { [weak self] buffer in
            self?.handleAudioBuffer(buffer)
        }
        self.streamOutput = output

        // Add audio output
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.echotune.systemaudio"))

        // Start the stream
        try await stream.startCapture()
        self.stream = stream

        await MainActor.run {
            self.isCapturing = true
        }

        debugLog("✅ SystemAudioCapture: System audio capture started (sampleRate: \(sampleRate), channels: \(channelCount))")
    }

    // MARK: - Stop Capture

    func stopCapture() async {
        guard isCapturing, let stream = stream else { return }

        debugLog("⏹ SystemAudioCapture: Stopping system audio capture...")

        do {
            try await stream.stopCapture()
        } catch {
            debugLog("⚠️ SystemAudioCapture: Error stopping stream: \(error)")
        }

        self.stream = nil
        self.streamOutput = nil

        await MainActor.run {
            self.isCapturing = false
            self.audioLevel = 0.0
        }

        debugLog("✅ SystemAudioCapture: System audio capture stopped")
    }

    // MARK: - Audio Resampling

    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    /// Lazily create a converter from the source format to our target 16kHz mono Float32 format.
    private func getOrCreateConverter(sourceFormat: AVAudioFormat) -> AVAudioConverter? {
        if let converter = converter { return converter }

        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        self.targetFormat = target

        guard let conv = AVAudioConverter(from: sourceFormat, to: target) else {
            debugLog("❌ SystemAudioCapture: Failed to create audio converter (\(sourceFormat) → \(target))")
            return nil
        }
        debugLog("✅ SystemAudioCapture: Audio converter created (\(sourceFormat.sampleRate)Hz → \(sampleRate)Hz)")
        self.converter = conv
        return conv
    }

    /// Resample a buffer to 16kHz mono. Returns nil if already at target format or on error.
    private func resampleBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let sourceFormat = buffer.format

        // If already at target rate and mono, no conversion needed
        if sourceFormat.sampleRate == sampleRate && sourceFormat.channelCount == 1 {
            return buffer
        }

        guard let conv = getOrCreateConverter(sourceFormat: sourceFormat),
              let target = targetFormat else { return nil }

        // Calculate output frame count based on sample rate ratio
        let ratio = sampleRate / sourceFormat.sampleRate
        let outputFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outputFrames) else { return nil }

        var error: NSError?
        let status = conv.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            debugLog("⚠️ SystemAudioCapture: Resample error: \(error?.localizedDescription ?? "unknown")")
            return nil
        }

        return outputBuffer
    }

    // MARK: - Audio Buffer Processing

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Resample to 16kHz mono if needed
        guard let processedBuffer = resampleBuffer(buffer) else { return }

        // Calculate audio level for visualisation
        if let channelData = processedBuffer.floatChannelData?[0] {
            let frameCount = Int(processedBuffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameCount {
                sum += abs(channelData[i])
            }
            let avgLevel = sum / Float(max(frameCount, 1))
            DispatchQueue.main.async { [weak self] in
                self?.audioLevel = avgLevel
            }
        }

        // Forward resampled buffer to callback
        onAudioBuffer?(processedBuffer)
    }
}

// MARK: - Stream Output Delegate

@available(macOS 13.0, *)
private class AudioStreamOutput: NSObject, SCStreamOutput {
    let onAudioBuffer: (AVAudioPCMBuffer) -> Void

    init(onAudioBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        self.onAudioBuffer = onAudioBuffer
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard let buffer = sampleBuffer.toAudioPCMBuffer() else { return }
        onAudioBuffer(buffer)
    }
}

// MARK: - CMSampleBuffer → AVAudioPCMBuffer Extension

extension CMSampleBuffer {
    func toAudioPCMBuffer() -> AVAudioPCMBuffer? {
        guard let formatDescription = formatDescription else { return nil }

        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = audioStreamBasicDescription?.pointee else { return nil }

        let format = AVAudioFormat(streamDescription: &(UnsafeMutablePointer(mutating: audioStreamBasicDescription)!.pointee))
        guard let audioFormat = format else { return nil }

        let numFrames = CMSampleBufferGetNumSamples(self)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(numFrames)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(numFrames)

        // Copy audio data
        guard let blockBuffer = CMSampleBufferGetDataBuffer(self) else { return nil }

        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)

        guard status == kCMBlockBufferNoErr, let data = dataPointer else { return nil }

        if let floatData = buffer.floatChannelData {
            // Float format
            let byteCount = min(totalLength, Int(buffer.frameCapacity) * MemoryLayout<Float>.size * Int(audioFormat.channelCount))
            memcpy(floatData[0], data, byteCount)
        } else if let int16Data = buffer.int16ChannelData {
            // Int16 format
            let byteCount = min(totalLength, Int(buffer.frameCapacity) * MemoryLayout<Int16>.size * Int(audioFormat.channelCount))
            memcpy(int16Data[0], data, byteCount)
        }

        return buffer
    }
}

// MARK: - Errors

enum SystemAudioCaptureError: LocalizedError {
    case noDisplayFound
    case permissionDenied
    case captureStartFailed

    var errorDescription: String? {
        switch self {
        case .noDisplayFound: return "No display found for audio capture"
        case .permissionDenied: return "Screen Recording permission required for meeting mode"
        case .captureStartFailed: return "Failed to start system audio capture"
        }
    }
}
