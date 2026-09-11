import Testing
@testable import EchoTune

struct StreamingTickTests {
    @Test func previewTiersRetainClassicRollbackAndExposeIntervals() {
        #expect(PreviewTier.classic.interval == 4.0)
        #expect(PreviewTier.balanced.interval == 2.0)
        #expect(PreviewTier.reactive.interval == 1.0)
        #expect(PreviewTier.allCases.contains(.classic))
    }

    @Test func startingANewSessionCancelsInFlightTickAndSettle() {
        let engine = WhisperEngine.shared
        let tick = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
        let settle = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
        engine.currentTickTask = tick
        engine.streamingTask = settle
        let oldSession = engine.streamingSessionID

        engine.cancelStreamingWorkForNewSession()

        #expect(tick.isCancelled)
        #expect(settle.isCancelled)
        #expect(engine.streamingSessionID != oldSession)

        engine.currentTickTask = nil
        engine.streamingTask = nil
    }

    @Test func cancellingStreamingWorkIsIdempotent() {
        let engine = WhisperEngine.shared
        let firstSession = engine.streamingSessionID

        engine.cancelStreamingWorkForNewSession()
        let secondSession = engine.streamingSessionID
        engine.cancelStreamingWorkForNewSession()

        #expect(secondSession != firstSession)
        #expect(engine.streamingSessionID != secondSession)
        engine.currentTickTask = nil
        engine.streamingTask = nil
    }
}
