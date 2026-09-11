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
}
