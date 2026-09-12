import AVFoundation
import Foundation
import FluidAudio
import Testing
@testable import EchoTune

struct VADTests {
    @Test func freshSettingsPreferSileroWithoutOverwritingDefaults() {
        let suite = "EchoTune.VADTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = VADManager(defaults: defaults)
        #expect(manager.config.method == .sileroVAD)
        #expect(manager.effectiveMethod == .energyBased || manager.effectiveMethod == .sileroVAD)
        #expect(defaults.string(forKey: "vadMethod") == nil)
    }

    @Test func configuredEnergyMethodStaysEnergyBased() {
        #expect(VADManager.effectiveMethod(configured: .energyBased, sileroReady: true) == .energyBased)
    }

    @Test func sileroUsesSileroOnlyWhenReady() {
        #expect(VADManager.effectiveMethod(configured: .sileroVAD, sileroReady: true) == .sileroVAD)
        #expect(VADManager.effectiveMethod(configured: .sileroVAD, sileroReady: false) == .energyBased)
    }

    @Test func energyFallbackDetectsSyntheticSpeech() async {
        let suite = "EchoTune.VADTests.energy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(VADManager.DetectionMethod.energyBased.rawValue, forKey: "vadMethod")
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = VADManager(defaults: defaults)
        let silence = Array(repeating: Float.zero, count: 16_000)
        let tone = (0..<48_000).map { index in
            sin(Float(index) * 2 * .pi * 220 / 16_000) * 0.1
        }
        let samples = silence + tone + silence
        let spans = try? await manager.speechSpans(in: samples)

        #expect(spans?.count == 1)
        #expect((spans?.first?.start ?? 0) >= 15_000)
        #expect((spans?.first?.end ?? 0) <= 65_000)
    }

    @Test func vadChunkMathMatchesFluidAudio() {
        #expect(FluidVADEngine.sampleRate == 16_000)
        #expect(4096 / FluidVADEngine.sampleRate == 0)
        #expect(Double(4096) / Double(FluidVADEngine.sampleRate) == 0.256)
    }

    @Test func syntheticThreeSecondRegionMapsWithinTolerance() {
        let segments = FluidVADEngine.speechSpans(
            from: [VadSegment(startTime: 1.0, endTime: 4.0)],
            sampleCount: 80_000
        )

        #expect(segments.count == 1)
        #expect(abs(Double(segments[0].start) / 16_000 - 1.0) < 0.15)
        #expect(abs(Double(segments[0].end) / 16_000 - 4.0) < 0.15)
    }

    // MARK: - Regression: frameLength propagation (7.4.3)

    /// A detector result must carry the true frame count. Before 7.4.3 every
    /// construction site omitted `frameLength`, so `analyzeSpeechSegments`
    /// summed zero frames, computed `0/0 = NaN`, and rejected every
    /// VAD-enabled recording as silent.
    @Test func detectedProbabilityCarriesFrameLength() throws {
        let suite = "EchoTune.VADTests.frame.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(VADManager.DetectionMethod.energyBased.rawValue, forKey: "vadMethod")
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = VADManager(defaults: defaults)
        let buffer = Self.makeBuffer(frames: 16_000, amplitude: 0.5)

        let result = manager.detectSpeech(in: buffer)

        #expect(result.frameLength == 16_000)
    }

    /// End-to-end: a loud synthetic buffer must be classified as speech.
    @Test func loudAudioIsNotRejectedAsSilent() throws {
        let suite = "EchoTune.VADTests.loud.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(VADManager.DetectionMethod.energyBased.rawValue, forKey: "vadMethod")
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = VADManager(defaults: defaults)
        let buffer = Self.makeBuffer(frames: 16_000, amplitude: 0.5)
        let detection = manager.detectSpeech(in: buffer)

        let analysis = manager.analyzeSpeechSegments(
            from: [detection],
            sampleRate: 16_000
        )

        #expect(!analysis.speechPercentage.isNaN)
        #expect(analysis.totalDuration > 0)
        #expect(analysis.hasSignificantSpeech)
    }

    /// A zero-frame history must not produce NaN or claim speech.
    @Test func zeroFrameHistoryDoesNotProduceNaN() {
        let suite = "EchoTune.VADTests.zero.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = VADManager(defaults: defaults)
        let zeroFrame = VADManager.SpeechProbability(
            probability: 0.9,
            timestamp: Date(),
            rmsLevel: 0.5,
            isSpeech: true,
            frameLength: 0
        )

        let analysis = manager.analyzeSpeechSegments(
            from: [zeroFrame],
            sampleRate: 16_000
        )

        #expect(!analysis.speechPercentage.isNaN)
        #expect(!analysis.hasSignificantSpeech)
    }

    /// Build a mono Float32 PCM buffer without an audio device.
    private static func makeBuffer(
        frames: AVAudioFrameCount,
        amplitude: Float
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        if let channel = buffer.floatChannelData?[0] {
            for i in 0..<Int(frames) {
                channel[i] = sin(Float(i) * 2 * .pi * 220 / 16_000) * amplitude
            }
        }
        return buffer
    }
}
