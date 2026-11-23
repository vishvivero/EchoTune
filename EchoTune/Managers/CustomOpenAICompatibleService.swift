//
//  CustomOpenAICompatibleService.swift
//  EchoTune
//
//  ET-766 · talk to any local or self-hosted OpenAI-compatible server.
//
//  WHY THIS EXISTS
//  ---------------
//  EchoTune could reach Groq, xAI, Gemini and OpenAI, and a hosted proxy. But the
//  people who most want private dictation already run their own inference:
//
//    · LM Studio            http://localhost:1234/v1
//    · Ollama (HTTP mode)   http://localhost:11434/v1
//    · vLLM                 http://localhost:8000/v1
//    · faster-whisper-server http://localhost:8000/v1
//    · OpenRouter           https://openrouter.ai/api/v1
//
//  All of those speak the OpenAI wire format for `/audio/transcriptions` and
//  `/chat/completions`. This file is the single place that knows how to reach
//  them, including normalising the base URL people actually paste
//  (`localhost:1234`, `…/v1`, `…/v1/chat/completions` …).
//

import Foundation

/// Normalisation + request building for OpenAI-compatible endpoints.
///
/// Deliberately free of networking: the URL maths and request shape are the parts
/// that break in the field, so they are unit-tested rather than exercised by hand.
enum CustomOpenAICompatibleService {

    // MARK: - Endpoint kinds

    enum EndpointKind: String, CaseIterable, Identifiable {
        case transcription = "/audio/transcriptions"
        case chat = "/chat/completions"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .transcription: return "Speech-to-text"
            case .chat: return "Chat / cleanup"
            }
        }

        /// How the path is spelled once the `/v1` prefix is resolved.
        var pathComponent: String {
            switch self {
            case .transcription: return "audio/transcriptions"
            case .chat: return "chat/completions"
            }
        }
    }

    // MARK: - Normalisation

    /// Turns whatever the user pasted into a usable base URL ending in `/v1`.
    ///
    /// Handles, in order:
    ///   · a missing scheme       → defaults to `http` for local hosts, `https` otherwise
    ///   · a trailing slash       → trimmed
    ///   · a full endpoint path   → reduced back to its base
    ///   · a missing `/v1`        → appended
    ///
    /// Returns `nil` for empty input or something that cannot be a host.
    static func normalizedBaseURL(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Strip a browser-pasted trailing slash and any query/fragment noise.
        if let queryStart = text.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            text = String(text[text.startIndex..<queryStart])
        }

        // A pasted full endpoint is the most common mistake: roll it back.
        for suffix in [
            "/v1/audio/transcriptions",
            "/v1/chat/completions",
            "/audio/transcriptions",
            "/chat/completions"
        ] where text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count))
            break
        }

        while text.hasSuffix("/") { text.removeLast() }
        guard !text.isEmpty else { return nil }

        // Default the scheme. Anything that is clearly a local host gets http.
        if !text.contains("://") {
            let lowered = text.lowercased()
            let isLocal = lowered.hasPrefix("localhost")
                || lowered.hasPrefix("127.0.0.1")
                || lowered.hasPrefix("0.0.0.0")
                || lowered.hasPrefix("[::1]")
                || lowered.hasPrefix("192.168.")
                || lowered.hasPrefix("10.")
            text = (isLocal ? "http://" : "https://") + text
        }

        // Append /v1 unless the base already carries an explicit version.
        let lowered = text.lowercased()
        let hasVersion = lowered.hasSuffix("/v1")
            || lowered.hasSuffix("/v1beta")
            || lowered.hasSuffix("/api/v1")
        if !hasVersion {
            text += "/v1"
        }

        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }

    /// Full URL for one endpoint, e.g. `http://localhost:1234/v1/chat/completions`.
    static func endpointURL(base: String, kind: EndpointKind) -> URL? {
        guard let baseURL = normalizedBaseURL(base) else { return nil }
        return baseURL.appendingPathComponent(kind.pathComponent)
    }

    // MARK: - Credentials

    /// True when a base URL points at this machine, so we can skip the API key
    /// requirement for LM Studio / Ollama / vLLM out of the box.
    static func isLocalEndpoint(_ raw: String) -> Bool {
        guard let url = normalizedBaseURL(raw), let host = url.host?.lowercased() else { return false }
        return host == "localhost"
            || host == "127.0.0.1"
            || host == "0.0.0.0"
            || host == "[::1]"
            || host == "::1"
            || host.hasPrefix("192.168.")
            || host.hasPrefix("10.")
            || host.hasSuffix(".local")
    }

    /// A key is only required for non-local endpoints.
    static func requiresAPIKey(_ raw: String) -> Bool {
        !isLocalEndpoint(raw)
    }

    // MARK: - Presets

    struct Preset: Identifiable {
        let id: String
        let name: String
        let baseURL: String
        let note: String

        static let all: [Preset] = [
            Preset(id: "lmstudio", name: "LM Studio", baseURL: "http://localhost:1234/v1",
                   note: "Start the local server in LM Studio (Developer tab)."),
            Preset(id: "ollama", name: "Ollama (HTTP)", baseURL: "http://localhost:11434/v1",
                   note: "Works even when the Ollama CLI is not on PATH."),
            Preset(id: "vllm", name: "vLLM", baseURL: "http://localhost:8000/v1",
                   note: "vLLM's OpenAI-compatible server."),
            Preset(id: "whisper-server", name: "faster-whisper-server", baseURL: "http://localhost:8000/v1",
                   note: "Self-hosted speech-to-text."),
            Preset(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1",
                   note: "Needs an OpenRouter key.")
        ]
    }

    // MARK: - Requests

    /// Builds the multipart body for `/audio/transcriptions`.
    static func transcriptionRequest(
        audio: Data,
        filename: String,
        model: String,
        language: String?,
        apiKey: String?,
        boundary: String = "Boundary-\(UUID().uuidString)"
    ) -> URLRequest? {
        guard !audio.isEmpty else { return nil }

        // The caller swaps in the real endpoint; the body is what this builds.
        guard let placeholder = URL(string: "https://example.invalid") else { return nil }
        var request = URLRequest(url: placeholder)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        applyAuthorization(apiKey, to: &request)

        var body = Data()
        func append(_ string: String) {
            if let data = string.data(using: .utf8) { body.append(data) }
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(audio)
        append("\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append(model)
        append("\r\n")

        if let language, !language.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            append(language)
            append("\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        append("json")
        append("\r\n")

        append("--\(boundary)--\r\n")

        request.httpBody = body
        return request
    }

    /// Builds the JSON body for `/chat/completions`.
    static func chatRequest(
        messages: [(role: String, content: String)],
        model: String,
        temperature: Double = 0.2,
        apiKey: String?
    ) -> (body: Data, isJSON: Bool)? {
        guard !messages.isEmpty, !model.isEmpty else { return nil }
        let payload: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return (data, true)
    }

    /// Adds `Authorization: Bearer …` only for endpoints that need it, so local
    /// servers are not sent a header they may reject.
    static func applyAuthorization(_ apiKey: String?, to request: inout URLRequest) {
        guard let apiKey, !apiKey.isEmpty else { return }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    // MARK: - Responses

    /// Extracts `text` from an OpenAI-compatible transcription response.
    ///
    /// Accepts `{"text": "…"}` and the verbose shape
    /// `{"segments": [...], "text": "…"}`; returns `nil` when the body has no text.
    static func transcriptionText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let text = object["text"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    /// Extracts `choices[0].message.content` from a chat completion.
    static func chatText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}