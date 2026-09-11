import Foundation
import os.log

/// Deepgram live WebSocket transcription. The caller owns fallback to the
/// existing REST service when this session throws or is marked degraded.
@MainActor
final class DeepgramStreamingService: CloudStreamingSession {
    let providerName = "Deepgram"

    enum StreamingError: Error, LocalizedError {
        case invalidConfiguration
        case notStarted
        case providerError(String)
        case socketClosed

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration: return "Deepgram streaming requires 16 kHz mono audio and an API key."
            case .notStarted: return "Deepgram streaming has not started."
            case .providerError(let message): return "Deepgram streaming error: \(message)"
            case .socketClosed: return "Deepgram streaming socket closed unexpectedly."
            }
        }
    }

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var sendChain: Task<Void, Never>?
    private var partialContinuation: AsyncStream<CloudPartial>.Continuation?
    private var finalSegments: [String] = []
    private var latestTranscript = ""
    private var receivedResultCount = 0
    private var active = false
    private var reconnectFailures = 0
    private var configuration: CloudStreamingConfig?
    private var degraded = false

    lazy var interim: AsyncStream<CloudPartial> = {
        AsyncStream { continuation in
            partialContinuation = continuation
        }
    }()

    func start(config: CloudStreamingConfig) async throws {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              config.sampleRate == 16_000 else {
            throw StreamingError.invalidConfiguration
        }

        cancel()
        let task = try makeSocket(config: config)
        configuration = config
        active = true
        degraded = false
        finalSegments.removeAll(keepingCapacity: true)
        latestTranscript = ""
        receivedResultCount = 0
        reconnectFailures = 0
        task.resume()
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func send(_ samples: [Float]) async {
        guard !samples.isEmpty else { return }

        // Audio callbacks create unstructured Tasks. Serialize their sends so
        // CloseStream cannot overtake the final PCM frame when the user stops.
        let previous = sendChain
        let next = Task { [weak self] in
            await previous?.value
            await self?.sendImmediately(samples)
        }
        sendChain = next
        await next.value
    }

    private func sendImmediately(_ samples: [Float]) async {
        guard active, let task = socket else { return }

        var pcm = [Int16](repeating: 0, count: samples.count)
        for (index, sample) in samples.enumerated() {
            let clipped = max(-1, min(1, sample))
            pcm[index] = Int16((clipped * Float(Int16.max)).rounded())
        }
        let data = pcm.withUnsafeBytes { Data($0) }
        await withCheckedContinuation { continuation in
            task.send(.data(data)) { _ in
                continuation.resume()
            }
        }
    }

    func finish() async throws -> String {
        let task = socket
        let isActive = active
        guard isActive, let task else { throw StreamingError.notStarted }
        if degraded { throw StreamingError.providerError("connection degraded after reconnect attempts") }

        // Wait for every PCM send queued by the audio callback before asking
        // Deepgram to finalize the stream.
        await sendChain?.value
        sendChain = nil

        let closeMessage = Data(#"{"type":"CloseStream"}"#.utf8)
        await withCheckedContinuation { continuation in
            task.send(.string(String(decoding: closeMessage, as: UTF8.self)) ) { _ in
                continuation.resume()
            }
        }
        // Deepgram can deliver the final Results frame after CloseStream.
        // Keep the stop path responsive; latestTranscript remains available if
        // the provider's final frame arrives after this bounded wait.
        try? await Task.sleep(for: .milliseconds(900))
        task.cancel(with: .normalClosure, reason: nil)
        receiveTask?.cancel()
        receiveTask = nil
        active = false
        let finalText = finalSegments.joined(separator: " ")
        let result = (finalText.isEmpty ? latestTranscript : finalText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        os_log("Deepgram stream closed: results=%d finalSegments=%d chars=%d", log: appLog, type: .info, receivedResultCount, finalSegments.count, result.count)
        partialContinuation?.finish()
        partialContinuation = nil
        socket = nil
        return result
    }

    func cancel() {
        active = false
        degraded = false
        configuration = nil
        let task = socket
        socket = nil
        let receiver = receiveTask
        receiveTask = nil
        sendChain?.cancel()
        sendChain = nil
        partialContinuation?.finish()
        partialContinuation = nil
        receiver?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
    }

    private func makeSocket(config: CloudStreamingConfig) throws -> URLSessionWebSocketTask {
        var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")!
        components.queryItems = [
            URLQueryItem(name: "model", value: config.model),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "300"),
            URLQueryItem(name: "smart_format", value: "true")
        ]
        if let language = config.language, !language.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "language", value: language))
        }
        guard let url = components.url else { throw StreamingError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.setValue("Token \(config.apiKey)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.webSocketTask(with: request)
        socket = task
        return task
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            let task = socket
            let isActive = active
            guard isActive, let task else { return }
            do {
                let message = try await task.receive()
                let data: Data?
                switch message {
                case .data(let value): data = value
                case .string(let value): data = value.data(using: .utf8)
                @unknown default: data = nil
                }
                guard let data, let partial = DeepgramMessage.parse(data) else { continue }
                receivedResultCount += 1
                latestTranscript = partial.text
                if partial.isFinal, !partial.text.isEmpty {
                    finalSegments.append(partial.text)
                }
                let continuation = partialContinuation
                continuation?.yield(partial)
            } catch {
                guard active, reconnectFailures < 2, let configuration else {
                    degraded = active
                    return
                }
                reconnectFailures += 1
                do {
                    let replacement = try makeSocket(config: configuration)
                    replacement.resume()
                    continue
                } catch {
                    degraded = true
                    return
                }
            }
        }
    }
}

/// Pure Deepgram Results-message parser. Metadata, utterance-end, malformed,
/// and provider error frames intentionally return nil.
enum DeepgramMessage {
    static func parse(_ data: Data, receivedAt: Date = Date()) -> CloudPartial? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "Results",
              let channel = object["channel"] as? [String: Any],
              let alternatives = channel["alternatives"] as? [[String: Any]],
              let transcript = alternatives.first?["transcript"] as? String else {
            return nil
        }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return CloudPartial(text: text, isFinal: object["is_final"] as? Bool ?? false, receivedAt: receivedAt)
    }
}
