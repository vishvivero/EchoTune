//
//  CustomOpenAICompatibleService.swift
//  EchoTune
//
//  Supports any OpenAI-compatible Speech-to-Text (/v1/audio/transcriptions)
//  and Chat Completion (/v1/chat/completions) server: LM Studio, OpenRouter,
//  vLLM, Jan, Ollama HTTP, faster-whisper-server, whisper.cpp server, etc.
//

import Foundation

final class CustomOpenAICompatibleService {
    static let shared = CustomOpenAICompatibleService()

    enum ServiceError: Error, LocalizedError {
        case invalidBaseURL
        case invalidResponse
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "Custom OpenAI Base URL is invalid. Check Settings › AI & Models."
            case .invalidResponse:
                return "Custom OpenAI endpoint returned an invalid response."
            case .httpError(let code, let detail):
                return detail.isEmpty ? "Custom endpoint HTTP \(code)" : "Custom endpoint HTTP \(code): \(detail)"
            }
        }
    }

    private init() {}

    static func normalizedEndpoint(baseURL: String, suffix: String) -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            trimmed = "http://\(trimmed)"
        }
        // Avoid duplicating /v1 if baseURL already ends with /v1 and suffix starts with /v1
        if trimmed.hasSuffix("/v1") && suffix.hasPrefix("/v1/") {
            let remainder = String(suffix.dropFirst(3))
            return URL(string: trimmed + remainder)
        }
        return URL(string: trimmed + suffix)
    }

    func completeChat(
        systemPrompt: String,
        userMessage: String,
        baseURL: String,
        modelID: String,
        apiKey: String
    ) async throws -> String {
        guard let url = Self.normalizedEndpoint(baseURL: baseURL, suffix: "/v1/chat/completions") else {
            throw ServiceError.invalidBaseURL
        }

        let effectiveModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "local-model" : modelID
        let payload: [String: Any] = [
            "model": effectiveModel,
            "temperature": 0.3,
            "max_tokens": 4000,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError(http.statusCode, String(raw.prefix(240)))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ServiceError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func transcribeAudio(
        audioData: Data,
        baseURL: String,
        modelID: String,
        language: String?,
        apiKey: String
    ) async throws -> String {
        guard let url = Self.normalizedEndpoint(baseURL: baseURL, suffix: "/v1/audio/transcriptions") else {
            throw ServiceError.invalidBaseURL
        }

        let boundary = "EchoTuneBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60

        var body = Data()
        let effectiveModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "whisper-1" : modelID

        func appendField(_ name: String, value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }

        appendField("model", value: effectiveModel)
        appendField("response_format", value: "json")
        if let language, !language.isEmpty {
            appendField("language", value: language)
        }

        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".utf8))
        body.append(Data("Content-Type: audio/wav\r\n\r\n".utf8))
        body.append(audioData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError(http.statusCode, String(raw.prefix(240)))
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let plain = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !plain.isEmpty {
            return plain
        }
        throw ServiceError.invalidResponse
    }
}
