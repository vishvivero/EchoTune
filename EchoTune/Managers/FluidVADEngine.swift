import Foundation
import CoreML
import FluidAudio

/// Sample-index speech region returned by the shipping FluidAudio VAD.
/// FluidAudio reports timestamps in seconds; EchoTune keeps the decode helper
/// independent of the package so it remains easy to test without model I/O.
struct FluidSpeechSpan: Equatable, Sendable {
    let start: Int
    let end: Int
}

/// Shipping Silero implementation for Phase 4.
///
/// FluidAudio owns model acquisition and CoreML loading. Keeping that work
/// behind this adapter means a missing network/model always degrades to the
/// energy detector instead of crashing the capture or decode path.
final class FluidVADEngine: @unchecked Sendable {
    static let shared = FluidVADEngine()

    static let sampleRate = 16_000
    static let modelCacheDirectory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("FluidAudio/Models", isDirectory: true)

    private let lock = NSLock()
    private var manager: VadManager?
    private(set) var isReady = false
    private var isPreparing = false

    private let segmentationConfig = VadSegmentationConfig(
        minSpeechDuration: 0.25,
        minSilenceDuration: 0.10,
        maxSpeechDuration: 14.0,
        speechPadding: 0.03
    )

    private init() {}

    /// Downloads/loads Silero through FluidAudio's supported model path.
    /// Repeated calls after readiness are no-ops; concurrent callers receive a
    /// clear error rather than starting duplicate downloads.
    func prepare(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        lock.lock()
        if isReady {
            lock.unlock()
            return
        }
        if isPreparing {
            lock.unlock()
            throw FluidVADError.preparationInProgress
        }
        isPreparing = true
        lock.unlock()

        defer {
            lock.lock()
            isPreparing = false
            lock.unlock()
        }

        do {
            let config = VadConfig(
                defaultThreshold: 0.5,
                debugMode: false,
                computeUnits: .all
            )
            let loadedManager = try await VadManager(config: config) { snapshot in
                progress?(snapshot.fractionCompleted)
            }
            let available = await loadedManager.isAvailable
            guard available else { throw FluidVADError.modelUnavailable }

            lock.lock()
            manager = loadedManager
            isReady = true
            lock.unlock()

            debugLog("✅ FluidAudio Silero VAD ready at \(Self.modelCacheDirectory.path)")
            progress?(1.0)
        } catch {
            lock.lock()
            isReady = false
            lock.unlock()
            debugLog("⚠️ FluidAudio Silero VAD unavailable: \(error.localizedDescription)")
            throw error
        }
    }

    /// Returns speech spans for 16 kHz mono Float32 samples.
    func segments(in samples: [Float]) async throws -> [SpeechSpan] {
        guard !samples.isEmpty else { return [] }

        lock.lock()
        let loadedManager = manager
        let ready = isReady
        lock.unlock()

        guard ready, let loadedManager else {
            throw FluidVADError.modelUnavailable
        }

        let segments = try await loadedManager.segmentSpeech(samples, config: segmentationConfig)
        return Self.speechSpans(from: segments, sampleCount: samples.count)
    }

    static func speechSpans(from segments: [VadSegment], sampleCount: Int) -> [SpeechSpan] {
        segments.map {
            SpeechSpan(
                start: max(0, min(sampleCount, $0.startSample(sampleRate: Self.sampleRate))),
                end: max(0, min(sampleCount, $0.endSample(sampleRate: Self.sampleRate)))
            )
        }.filter(\.isValid)
    }
}

enum FluidVADError: LocalizedError {
    case modelUnavailable
    case preparationInProgress

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "The FluidAudio Silero VAD model is unavailable."
        case .preparationInProgress:
            return "The FluidAudio Silero VAD model is already preparing."
        }
    }
}
