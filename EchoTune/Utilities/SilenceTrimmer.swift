import Foundation

/// A speech region expressed as sample indices in a 16 kHz mono buffer.
struct SpeechSpan: Equatable, Sendable {
    let start: Int
    let end: Int

    var isValid: Bool { end > start }
}

/// Pure audio-window trimming used before WhisperKit decoding.
enum SilenceTrimmer {
    /// Keeps speech spans, pads and merges them, and returns nil when the
    /// remaining audio is too short to decode safely.
    static func trim(
        samples: [Float],
        spans: [SpeechSpan],
        sampleRate: Double,
        padding: Double = 0.05,
        mergeGap: Double = 0.25,
        minimumLength: Double = 0.5
    ) -> [Float]? {
        guard !samples.isEmpty, !spans.isEmpty, sampleRate > 0 else { return nil }

        let paddingSamples = max(0, Int((padding * sampleRate).rounded()))
        let mergeGapSamples = max(0, Int((mergeGap * sampleRate).rounded()))
        let minimumSamples = max(1, Int((minimumLength * sampleRate).rounded()))

        let padded = spans
            .filter(\.isValid)
            .map { span in
                SpeechSpan(
                    start: max(0, min(samples.count, span.start - paddingSamples)),
                    end: max(0, min(samples.count, span.end + paddingSamples))
                )
            }
            .filter(\.isValid)
            .sorted { $0.start < $1.start }

        guard !padded.isEmpty else { return nil }

        var merged: [SpeechSpan] = []
        for span in padded {
            guard let previous = merged.last else {
                merged.append(span)
                continue
            }

            if span.start <= previous.end + mergeGapSamples {
                merged[merged.count - 1] = SpeechSpan(
                    start: previous.start,
                    end: max(previous.end, span.end)
                )
            } else {
                merged.append(span)
            }
        }

        let keptSamples = merged.reduce(0) { $0 + ($1.end - $1.start) }
        guard keptSamples >= minimumSamples else { return nil }

        var output: [Float] = []
        output.reserveCapacity(keptSamples)
        for span in merged {
            output.append(contentsOf: samples[span.start..<span.end])
        }
        return output
    }
}
