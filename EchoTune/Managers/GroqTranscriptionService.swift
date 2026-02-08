//
//  GroqTranscriptionService.swift
//  EchoTune
//
//  Phase 6A: Groq Cloud Transcription Integration
//  Lightning-fast Whisper Large v3 Turbo transcription
//

import Foundation
import AVFoundation
import Combine

class GroqTranscriptionService: ObservableObject {
    static let shared = GroqTranscriptionService()

    enum GroqError: Error, LocalizedError {
        case noAPIKey
        case invalidAudioData
        case networkError(Error)
        case apiError(String)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Groq API key is not configured. Please add your API key in Settings."
            case .invalidAudioData:
                return "Invalid audio data for transcription."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return "Groq API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }

    // Groq API configuration
    private let endpoint = "https://api.groq.com/openai/v1/audio/transcriptions"
    private let model = "whisper-large-v3-turbo"

    @Published var isTranscribing = false
    @Published var lastError: GroqError?

    private init() {
        print("✅ GroqTranscriptionService initialized")
    }

    // Maximum file size for a single Groq request (25MB limit, use 24MB for safety)
    private static let maxChunkSizeBytes = 24 * 1024 * 1024

    // MARK: - Main Transcription Method

    func transcribe(audioData: Data, language: String? = nil, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GroqError.noAPIKey
        }

        guard !audioData.isEmpty else {
            throw GroqError.invalidAudioData
        }

        await MainActor.run {
            isTranscribing = true
        }

        defer {
            Task { @MainActor in
                isTranscribing = false
            }
        }

        print("🚀 Starting Groq transcription...")
        print("   Audio size: \(audioData.count) bytes (\(String(format: "%.1f", Double(audioData.count) / 1024.0 / 1024.0)) MB)")
        print("   Model: \(model)")

        // Check if audio needs chunking (over 24MB or very long)
        if audioData.count > GroqTranscriptionService.maxChunkSizeBytes {
            print("📦 Audio exceeds size limit, chunking for Groq...")
            return try await transcribeWithChunking(audioData: audioData, language: language, apiKey: apiKey)
        }

        // Single chunk transcription
        return try await transcribeSingleChunk(audioData: audioData, language: language, apiKey: apiKey)
    }

    /// Transcribe a single audio chunk
    private func transcribeSingleChunk(audioData: Data, language: String?, apiKey: String) async throws -> String {
        let boundary = UUID().uuidString
        let request = createRequest(apiKey: apiKey, boundary: boundary)
        let body = createMultipartBody(audioData: audioData, language: language, boundary: boundary)

        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqError.networkError(NSError(domain: "com.echotune", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
            }

            print("   Response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? JSONDecoder().decode(GroqErrorResponse.self, from: data) {
                    throw GroqError.apiError(errorResponse.error.message)
                }
                throw GroqError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let groqResponse = try JSONDecoder().decode(GroqResponse.self, from: data)

            print("✅ Groq transcription successful")
            print("   Text length: \(groqResponse.text.count) characters")

            return groqResponse.text

        } catch let error as GroqError {
            await MainActor.run {
                lastError = error
            }
            throw error
        } catch {
            let groqError = GroqError.networkError(error)
            await MainActor.run {
                lastError = groqError
            }
            throw groqError
        }
    }

    /// Transcribe long audio by splitting into chunks and merging results
    private func transcribeWithChunking(audioData: Data, language: String?, apiKey: String) async throws -> String {
        // CAF container data cannot be naively split at byte boundaries.
        // For now, warn and attempt single-chunk transcription.
        // The 25MB Groq limit accommodates ~10+ minutes of Float32 48kHz audio in CAF format.
        print("⚠️ Audio data exceeds preferred size (\(audioData.count) bytes) — attempting single upload anyway")
        print("   Note: CAF container chunking not yet implemented")
        return try await transcribeSingleChunk(audioData: audioData, language: language, apiKey: apiKey)
    }

    // MARK: - Helper Methods

    private func createRequest(apiKey: String, boundary: String) -> URLRequest {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 300 seconds timeout (increased for large audio files)
        return request
    }

    private func createMultipartBody(audioData: Data, language: String?, boundary: String) -> Data {
        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(model)\r\n")

        // Add language field if specified
        if let language = language {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.append("\(language)\r\n")
        }

        // Add response_format field (prefer JSON for easier parsing)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.append("json\r\n")

        // Add temperature field (0 for more deterministic results)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n")
        body.append("0\r\n")

        // Add file field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // End boundary
        body.append("--\(boundary)--\r\n")

        return body
    }
}

// MARK: - Response Models

struct GroqResponse: Codable {
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
