import Testing
@testable import EchoTune

struct StreamingFallbackTests {
    @Test func dispositionCoversSpeechFallbackAndNoSpeech() {
        #expect(AgreementEngine.disposition(
            hasAudio: false,
            shouldFallback: true,
            audioDuration: 1
        ) == .noSpeech)
        #expect(AgreementEngine.disposition(
            hasAudio: true,
            shouldFallback: false,
            audioDuration: 1
        ) == .streamed)
        #expect(AgreementEngine.disposition(
            hasAudio: true,
            shouldFallback: true,
            audioDuration: 1
        ) == .batchFallback)
    }

    @Test func longSessionSkipsExpensiveBatchFallbackAtBoundary() {
        let limit = AgreementEngine.maxBatchFallbackDuration
        #expect(AgreementEngine.disposition(
            hasAudio: true,
            shouldFallback: true,
            audioDuration: limit
        ) == .batchFallback)
        #expect(AgreementEngine.disposition(
            hasAudio: true,
            shouldFallback: true,
            audioDuration: limit + 0.001
        ) == .streamed)
    }

    @Test func fallbackRequiresAgreementEngineRequest() {
        #expect(AgreementEngine.disposition(
            hasAudio: true,
            shouldFallback: false,
            audioDuration: 1
        ) == .streamed)
    }
}
