import Foundation

/// A live transcription connection owned by one cloud dictation session.
/// Implementations must tolerate frequent `send` calls without retaining an
/// unbounded audio queue. On an unexpected connection loss they may retry at
/// most twice; after that they must fail so the caller can use batch fallback.
@MainActor
protocol CloudStreamingSession: AnyObject {
    var providerName: String { get }

    /// Opens the provider connection and validates authentication.
    func start(config: CloudStreamingConfig) async throws

    /// Sends 16 kHz mono PCM samples. Implementations own conversion and
    /// backpressure; this method must not retain unbounded audio.
    func send(_ samples: [Float]) async

    /// Provider interim and final segment events.
    var interim: AsyncStream<CloudPartial> { get }

    /// Ends the stream and returns the joined final transcript.
    func finish() async throws -> String

    /// Idempotently closes the connection and cancels receive work.
    func cancel()
}

struct CloudPartial: Sendable, Equatable {
    let text: String
    let isFinal: Bool
    let receivedAt: Date
}

struct CloudStreamingConfig: Sendable {
    let apiKey: String
    let model: String
    let language: String?
    let sampleRate: Double

    init(apiKey: String, model: String, language: String? = nil, sampleRate: Double = 16_000) {
        self.apiKey = apiKey
        self.model = model
        self.language = language
        self.sampleRate = sampleRate
    }
}
