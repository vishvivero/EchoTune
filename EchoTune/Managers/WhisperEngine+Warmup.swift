//
//  WhisperEngine+Warmup.swift
//  EchoTune
//
//  Phase 1 (7.2.0) — warm start.
//
//  A real decode immediately after the model reports ready keeps the first
//  user dictation from paying CoreML kernel setup and decoder-cache warmup.
//  WhisperKit's own `prewarm:` flag blocks the load path (on a cold cache it
//  stalled onboarding for minutes), so warmup runs *after* the model is
//  usable: non-blocking, bounded, guarded, and never fatal.
//

import Foundation
import AVFoundation
import WhisperKit
import os.log

extension WhisperEngine {

    /// Why a warmup was or wasn't run.
    enum WarmupDecision: Equatable {
        case run
        case disabled
        case alreadyWarming
        case processing
        case engineUnavailable
        case cooldown
    }

    /// Outcome of one `performWarmup()` call.
    enum WarmupOutcome: Equatable {
        case completed(milliseconds: Int)
        case skipped(WarmupDecision)
        case skippedNoEngine
        case skippedNoSample
        case failed(String)
    }

    /// Bundled sample: 16 kHz mono, ~1.05 s of speech, 37 KB.
    static let warmupSampleName = "warmup"

    /// Minimum gap between warmups, so wake-spam can't re-decode repeatedly.
    static let warmupCooldown: TimeInterval = 60

    private static var didLogMissingSample = false

    /// Test seam: replaces the real WhisperKit decode so the warmup path can
    /// be exercised without a loaded model. Production leaves this nil.
    static var warmupDecodeOverride: (([Float]) async throws -> Void)?

    /// The bundled warmup sample, if it shipped. `bundle` is injectable so
    /// tests can assert the resource is actually present.
    static func warmupSampleURL(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: warmupSampleName, withExtension: "wav")
    }

    // MARK: - Decision

    /// Whether a warmup may run right now. Deliberately pure — no side
    /// effects — so every guard is unit-testable without a loaded model.
    func warmupDecision(now: Date = Date()) -> WarmupDecision {
        guard AppSettings.shared.warmupEnabled else { return .disabled }
        guard !isWarmingUp else { return .alreadyWarming }
        guard !isProcessing else { return .processing }
        // The override seam replaces the real engine, so it also bypasses the
        // availability check — letting tests exercise the decode path without
        // a loaded model.
        guard isAvailable || Self.warmupDecodeOverride != nil else { return .engineUnavailable }
        if let lastWarmupAt, now.timeIntervalSince(lastWarmupAt) < Self.warmupCooldown {
            return .cooldown
        }
        return .run
    }

    // MARK: - Entry Points

    /// Fire-and-forget warmup. Safe to call from anywhere, including paths
    /// where the model is already resident and no load will happen.
    func warmupIfNeeded() {
        guard warmupDecision() == .run else { return }
        Task(priority: .utility) { [weak self] in
            await self?.performWarmup()
        }
    }

    /// Runs one warmup decode and reports what happened. Awaitable so tests
    /// are deterministic; production reaches this through `warmupIfNeeded()`.
    ///
    /// The sample load and conversion run on the caller's actor (a ~1 ms
    /// read of a 37 KB file); the decode itself is WhisperKit's own async
    /// path, so the heavy CoreML work never occupies the main thread.
    @discardableResult
    func performWarmup() async -> WarmupOutcome {
        let decision = warmupDecision()
        guard decision == .run else {
            UserDefaults.standard.set(true, forKey: "perfLastWarmupSkipped")
            return .skipped(decision)
        }

        guard let url = Self.warmupSampleURL() else {
            if !Self.didLogMissingSample {
                Self.didLogMissingSample = true
                debugLog("⚠️ Warmup sample missing from the app bundle — skipping warmup")
            }
            UserDefaults.standard.set(true, forKey: "perfLastWarmupSkipped")
            return .skippedNoSample
        }

        isWarmingUp = true
        defer { isWarmingUp = false }

        let started = Date()
        do {
            let samples = try loadWarmupSamples(at: url)

            if let override = Self.warmupDecodeOverride {
                try await override(samples)
            } else {
                guard let whisperKit = whisperKitRef else { return .skippedNoEngine }
                // Greedy, single attempt, no detection: this is a cache-fill,
                // not a transcription. Failures are expected and harmless.
                let options = DecodingOptions(
                    task: .transcribe,
                    language: "en",
                    temperature: 0,
                    temperatureFallbackCount: 0,
                    detectLanguage: false,
                    skipSpecialTokens: true
                )
                _ = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
            }

            let milliseconds = Int(Date().timeIntervalSince(started) * 1000)
            lastWarmupAt = Date()
            warmupCompletionCount += 1
            // Phase 10 reads these back for the local perf dashboard.
            UserDefaults.standard.set(milliseconds, forKey: "perfLastWarmupMs")
            UserDefaults.standard.set(false, forKey: "perfLastWarmupSkipped")
            debugLog("🔥 Warmup decode done in \(milliseconds)ms")
            return .completed(milliseconds: milliseconds)
        } catch {
            // Best-effort by design: a failed warmup must never surface.
            UserDefaults.standard.set(true, forKey: "perfLastWarmupSkipped")
            debugLog("⚠️ Warmup decode failed (ignored): \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Sample Loading

    /// Reads the bundled sample and converts it into the 16 kHz mono Float
    /// stream WhisperKit consumes, reusing the shared conversion helpers
    /// rather than introducing a second resampler.
    func loadWarmupSamples(at url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else {
            throw WhisperError.audioFormatError
        }
        try file.read(into: buffer)
        return try convertBufferToFloatArray(buffer)
    }
}
