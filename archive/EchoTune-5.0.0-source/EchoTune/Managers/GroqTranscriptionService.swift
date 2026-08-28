//
//  GroqTranscriptionService.swift
//  EchoTune
//
//  Phase 6A: Cloud transcription integration for Groq Whisper and xAI Grok STT
//

import Foundation
import AVFoundation
import Combine

class GroqTranscriptionService: ObservableObject {
    static let shared = GroqTranscriptionService()

    enum Provider: Equatable {
        case groq
        case xai

        var displayName: String {
            switch self {
            case .groq:
                return "Groq"
            case .xai:
                return "xAI Grok"
            }
        }

        var endpoint: String {
            switch self {
            case .groq:
                return "https://api.groq.com/openai/v1/audio/transcriptions"
            case .xai:
                return "https://api.x.ai/v1/stt"
            }
        }

        var model: String? {
            switch self {
            case .groq:
                return "whisper-large-v3-turbo"
            case .xai:
                return nil
            }
        }
    }

    enum GroqError: Error, LocalizedError {
        case noAPIKey
        case invalidAudioData
        case emptyTranscription(String)
        case networkError(Error)
        case apiError(String)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No cloud transcription API key is configured. Add a Groq (gsk_…) or xAI Grok (xai-…) key in Settings."
            case .invalidAudioData:
                return "Invalid audio data for transcription."
            case .emptyTranscription(let provider):
                return "\(provider) returned an empty transcript, so nothing was saved to history."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return message
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }

    @Published var isTranscribing = false
    @Published var lastError: GroqError?

    private init() {
        debugLog("✅ GroqTranscriptionService initialized")
    }

    // Maximum file size for a single request (25MB limit, use 24MB for safety)
    private static let maxChunkSizeBytes = 24 * 1024 * 1024

    static func provider(for apiKey: String) -> Provider {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("xai-") {
            return .xai
        }
        return .groq
    }

    static func providerDisplayName(for apiKey: String) -> String {
        provider(for: apiKey).displayName
    }

    // MARK: - Main Transcription Method

    func transcribe(audioData: Data, language: String? = nil, apiKey: String) async throws -> String {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAPIKey.isEmpty else {
            throw GroqError.noAPIKey
        }

        guard !audioData.isEmpty else {
            throw GroqError.invalidAudioData
        }

        let provider = Self.provider(for: trimmedAPIKey)

        await MainActor.run {
            isTranscribing = true
        }

        defer {
            Task { @MainActor in
                isTranscribing = false
            }
        }

        debugLog("🚀 Starting cloud transcription...")
        debugLog("   Provider: \(provider.displayName)")
        debugLog("   Audio size: \(audioData.count) bytes (\(String(format: "%.1f", Double(audioData.count) / 1024.0 / 1024.0)) MB)")
        if let model = provider.model {
            debugLog("   Model: \(model)")
        }

        if audioData.count > GroqTranscriptionService.maxChunkSizeBytes {
            debugLog("📦 Audio exceeds size limit, chunking for \(provider.displayName)...")
            return try await transcribeWithChunking(audioData: audioData, language: language, apiKey: trimmedAPIKey, provider: provider)
        }

        return try await transcribeSingleChunk(audioData: audioData, language: language, apiKey: trimmedAPIKey, provider: provider)
    }

    /// Transcribe a single audio chunk
    private func transcribeSingleChunk(audioData: Data, language: String?, apiKey: String, provider: Provider) async throws -> String {
        let boundary = UUID().uuidString
        let request = createRequest(apiKey: apiKey, boundary: boundary, provider: provider)
        let body = createMultipartBody(audioData: audioData, language: language, boundary: boundary, provider: provider)

        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqError.networkError(NSError(domain: "com.echotune", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
            }

            debugLog("   Response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                let message = extractAPIErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                throw GroqError.apiError("\(provider.displayName) API error: \(message)")
            }

            let transcriptResponse: TranscriptionResponse
            do {
                transcriptResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            } catch {
                throw GroqError.decodingError(error)
            }

            let trimmedText = transcriptResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                throw GroqError.emptyTranscription(provider.displayName)
            }

            debugLog("✅ \(provider.displayName) transcription successful")
            debugLog("   Text length: \(trimmedText.count) characters")

            return trimmedText

        } catch let error as GroqError {
            await MainActor.run {
                lastError = error
            }
            throw error
        } catch {
            let wrappedError = GroqError.networkError(error)
            await MainActor.run {
                lastError = wrappedError
            }
            throw wrappedError
        }
    }

    /// Transcribe long audio by splitting into chunks and merging results
    private func transcribeWithChunking(audioData: Data, language: String?, apiKey: String, provider: Provider) async throws -> String {
        // CAF/WAV container data cannot be naively split at byte boundaries.
        // For now, warn and attempt single-chunk transcription.
        debugLog("⚠️ Audio data exceeds preferred size (\(audioData.count) bytes) — attempting single upload anyway")
        debugLog("   Note: container-aware chunking not yet implemented")
        return try await transcribeSingleChunk(audioData: audioData, language: language, apiKey: apiKey, provider: provider)
    }

    // MARK: - Helper Methods

    private func createRequest(apiKey: String, boundary: String, provider: Provider) -> URLRequest {
        var request = URLRequest(url: URL(string: provider.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300
        return request
    }

    private func createMultipartBody(audioData: Data, language: String?, boundary: String, provider: Provider) -> Data {
        var body = Data()

        if let model = provider.model {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
            body.append("\(model)\r\n")
        }

        if provider == .groq, let language = language {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.append("\(language)\r\n")
        }

        if provider == .groq, AppSettings.shared.translateToEnglish {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"task\"\r\n\r\n")
            body.append("translate\r\n")
        }

        if provider == .groq {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
            body.append("json\r\n")

            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n")
            body.append("0\r\n")
        }

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        return body
    }

    private func extractAPIErrorMessage(from data: Data) -> String? {
        if let errorResponse = try? JSONDecoder().decode(GroqErrorResponse.self, from: data) {
            return errorResponse.error.message
        }

        if let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let error = object["error"] as? String {
                return error
            }
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let message = object["message"] as? String {
                return message
            }
            if let detail = object["detail"] as? String {
                return detail
            }
        }

        if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }

        return nil
    }
}

// MARK: - Response Models

struct TranscriptionResponse: Codable {
    let text: String
}

struct GroqErrorResponse: Codable {
    let error: GroqErrorDetail
}

struct GroqErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Data Extension for String Appending

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
