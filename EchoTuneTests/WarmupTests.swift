//
//  WarmupTests.swift
//  EchoTuneTests
//
//  Phase 1 (7.2.0) — warm start.
//
//  The warmup exists to make the first dictation fast, which means it must
//  never be the thing that makes anything slower: it runs once per cold
//  start, it skips itself while the engine is busy, and a failed decode is
//  swallowed. These tests pin that contract.
//

import Foundation
import Testing
@testable import EchoTune

@MainActor
struct WarmupTests {

    // MARK: - Helpers

    /// Resets the singleton's warmup state and installs a decode stub that
    /// records how many times it was called. The stub also satisfies the
    /// availability guard, so the decode path is reachable without a model.
    private func stubEngine(onDecode: @escaping () -> Void = {}) -> WhisperEngine {
        let engine = WhisperEngine.shared
        engine.lastWarmupAt = nil
        engine.warmupCompletionCount = 0
        engine.isWarmingUp = false
        engine.isProcessing = false
        WhisperEngine.warmupDecodeOverride = { _ in onDecode() }
        return engine
    }

    /// Clears the test seam so it can never leak into another test (or into
    /// the app host process, which shares this singleton).
    private func clearStub() {
        WhisperEngine.warmupDecodeOverride = nil
    }

    /// Runs `body` with the warmup setting forced, restoring the real user's
    /// value afterwards — tests share the app's actual UserDefaults domain.
    private func withWarmupEnabled(_ enabled: Bool, _ body: () async -> Void) async {
        let settings = AppSettings.shared
        let original = settings.warmupEnabled
        settings.warmupEnabled = enabled
        defer { settings.warmupEnabled = original }
        await body()
    }

    // MARK: - Running

    @Test func warmupDecodesOnceThenRespectsCooldown() async {
        await withWarmupEnabled(true) {
            let engine = stubEngine()
            defer { clearStub() }

            let first = await engine.performWarmup()
            guard case .completed(let milliseconds) = first else {
                Issue.record("expected .completed, got \(first)")
                return
            }
            #expect(milliseconds >= 0)
            #expect(engine.warmupCompletionCount == 1)
            #expect(engine.lastWarmupAt != nil)

            // Second call inside the cooldown window must not decode again.
            let second = await engine.performWarmup()
            #expect(second == .skipped(.cooldown))
            #expect(engine.warmupCompletionCount == 1)
        }
    }

    @Test func warmupIsSkippedWhenDisabled() async {
        await withWarmupEnabled(false) {
            var decodeCalls = 0
            let engine = stubEngine { decodeCalls += 1 }
            defer { clearStub() }

            let outcome = await engine.performWarmup()
            #expect(outcome == .skipped(.disabled))
            #expect(decodeCalls == 0)
            #expect(engine.warmupCompletionCount == 0)
        }
    }

    @Test func warmupIsSkippedWhileTheEngineIsBusy() async {
        await withWarmupEnabled(true) {
            let engine = stubEngine()
            defer { clearStub() }

            engine.isProcessing = true
            #expect(engine.warmupDecision() == .processing)
            engine.isProcessing = false

            engine.isWarmingUp = true
            #expect(engine.warmupDecision() == .alreadyWarming)
            engine.isWarmingUp = false

            #expect(engine.warmupDecision() == .run)
        }
    }

    @Test func warmupDoesNotDecodeWithoutAnEngineOrStub() async {
        await withWarmupEnabled(true) {
            let engine = WhisperEngine.shared
            clearStub()

            let wasAvailable = engine.isAvailable
            let wasLoaded = engine.loadedModelName
            let wasWarming = engine.isWarmingUp
            let wasProcessing = engine.isProcessing
            let wasLastWarmup = engine.lastWarmupAt
            // The test process has no model loaded; force the state explicitly
            // so this assertion cannot depend on the host app's model state.
            engine.isAvailable = false
            engine.isWarmingUp = false
            engine.isProcessing = false
            engine.lastWarmupAt = nil
            defer {
                engine.isAvailable = wasAvailable
                engine.loadedModelName = wasLoaded
                engine.isWarmingUp = wasWarming
                engine.isProcessing = wasProcessing
                engine.lastWarmupAt = wasLastWarmup
            }

            #expect(engine.warmupDecision() == .engineUnavailable)
            let outcome = await engine.performWarmup()
            #expect(outcome == .skipped(.engineUnavailable))
        }
    }

    // MARK: - Failure handling

    @Test func aFailedWarmupIsSwallowedAndDoesNotStartTheCooldown() async {
        await withWarmupEnabled(true) {
            let engine = WhisperEngine.shared
            engine.lastWarmupAt = nil
            engine.warmupCompletionCount = 0
            WhisperEngine.warmupDecodeOverride = { _ in
                throw WhisperEngine.WhisperError.audioFormatError
            }
            defer { clearStub() }

            let outcome = await engine.performWarmup()
            guard case .failed = outcome else {
                Issue.record("expected .failed, got \(outcome)")
                return
            }
            // A failed warmup must not consume the cooldown — the next cold
            // moment should be free to try again.
            #expect(engine.lastWarmupAt == nil)
            #expect(engine.warmupCompletionCount == 0)
            #expect(engine.isWarmingUp == false)
        }
    }

    // MARK: - Sample

    @Test func warmupSampleIsBundled() throws {
        let url = try #require(
            WhisperEngine.warmupSampleURL(),
            "warmup.wav is missing from the app bundle — the warmup would no-op at runtime"
        )
        let samples = try WhisperEngine.shared.loadWarmupSamples(at: url)
        #expect(samples.count > 8_000, "expected ~1s of 16 kHz audio, got \(samples.count) samples")

        let peak = samples.map { abs($0) }.max() ?? 0
        #expect(peak > 0.01, "sample is silent — the warmup decode would do nothing useful")
    }

    @Test func warmupSampleLookupReturnsNilForABundleWithoutIt() {
        // A bundle that certainly does not carry the fixture.
        let empty = Bundle(for: BundleMarker.self)
        #expect(WhisperEngine.warmupSampleURL(in: empty) == nil)
    }
}

/// Anchor class used only to obtain a bundle that is not the app bundle.
private final class BundleMarker {}