import Testing
@testable import EchoTune

struct SilenceTrimTests {
    @Test func emptySpansSkipDecode() {
        let samples = Array(repeating: Float(0.2), count: 16_000)
        #expect(SilenceTrimmer.trim(samples: samples, spans: [], sampleRate: 16_000) == nil)
    }

    @Test func spanShorterThanMinimumSkipsDecode() {
        let samples = Array(repeating: Float(0.2), count: 16_000)
        let result = SilenceTrimmer.trim(
            samples: samples,
            spans: [SpeechSpan(start: 2_000, end: 8_000)],
            sampleRate: 16_000,
            padding: 0,
            minimumLength: 0.5
        )
        #expect(result == nil)
    }

    @Test func closeSpansMergeAndPreserveOrder() {
        let samples = (0..<80_000).map { Float($0) }
        let result = SilenceTrimmer.trim(
            samples: samples,
            spans: [
                SpeechSpan(start: 16_000, end: 24_000),
                SpeechSpan(start: 26_000, end: 34_000)
            ],
            sampleRate: 16_000,
            padding: 0,
            mergeGap: 0.25,
            minimumLength: 0.5
        )

        #expect(result?.count == 18_000)
        #expect(result?.first == 16_000)
        #expect(result?.last == 33_999)
    }

    @Test func paddingClampsAtBufferEdges() {
        let samples = Array(repeating: Float(1), count: 16_000)
        let result = SilenceTrimmer.trim(
            samples: samples,
            spans: [SpeechSpan(start: 100, end: 15_900)],
            sampleRate: 16_000,
            padding: 0.05,
            minimumLength: 0.5
        )
        #expect(result?.count == 16_000)
    }

    @Test func separatedSpansRemainOrdered() {
        let samples = (0..<32_000).map { Float($0) }
        let result = SilenceTrimmer.trim(
            samples: samples,
            spans: [
                SpeechSpan(start: 1_000, end: 10_000),
                SpeechSpan(start: 20_000, end: 30_000)
            ],
            sampleRate: 16_000,
            padding: 0,
            mergeGap: 0.1,
            minimumLength: 0.5
        )
        #expect(result?.count == 19_000)
        #expect(result?.first == 1_000)
        #expect(result?.last == 29_999)
    }
}
