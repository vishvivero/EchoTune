//
//  DeepgramTranscriptionService.swift
//  EchoTune
//
//  Phase 6B: Deepgram Cloud Transcription Integration
//  Fast, accurate, and cost-effective transcription
//

import Foundation
import AVFoundation
import Combine

class DeepgramTranscriptionService: ObservableObject {
    static let shared = DeepgramTranscriptionService()

    enum DeepgramModel: String {
        case nova = "nova-2"
        case novaMedical = "nova-2-medical"
        case novaPhonecall = "nova-2-phonecall"
        case whisperCloud = "whisper-cloud"

        var displayName: String {
            switch self {
            case .nova: return "Nova-2 (General)"
            case .novaMedical: return "Nova-2 Medical"
            case .novaPhonecall: return "Nova-2 Phonecall"
            case .whisperCloud: return "Whisper Cloud"
            }
        }
    }

    enum DeepgramError: Error, LocalizedError {
        case noAPIKey
        case invalidAudioData
        case networkError(Error)
        case apiError(String, Int)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Deepgram API key is not configured. Please add your API key in Settings."
            case .invalidAudioData:
                return "Invalid audio data for transcription."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message, let code):
                return "Deepgram API error (\(code)): \(message)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }

    @Published var isTranscribing = false
    @Published var lastError: DeepgramError?

    private let endpoint = "https://api.deepgram.com/v1/listen"

    private init() {
        print("✅ DeepgramTranscriptionService initialized")
    }

    // MARK: - Main Transcription Method

    func transcribe(
        audioData: Data,
        model: DeepgramModel = .nova,
        language: String? = nil,
        punctuate: Bool = true,
        diarize: Bool = false,
        apiKey: String
    ) async throws -> DeepgramResponse {
        guard !apiKey.isEmpty else {
            throw DeepgramError.noAPIKey
        }

        guard !audioData.isEmpty else {
            throw DeepgramError.invalidAudioData
        }

        await MainActor.run {
            isTranscribing = true
        }

        defer {
            Task { @MainActor in
                isTranscribing = false
            }
        }

        print("🚀 Starting Deepgram transcription...")
        print("   Audio size: \(audioData.count) bytes (\(String(format: "%.1f", Double(audioData.count) / 1024.0 / 1024.0)) MB)")
        print("   Model: \(model.displayName)")

        // Build query parameters
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: model.rawValue),
            URLQueryItem(name: "punctuate", value: String(punctuate))
        ]

        if let language = language {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }

        if diarize {
            queryItems.append(URLQueryItem(name: "diarize", value: "true"))
        }

        // Smart formatting
        queryItems.append(URLQueryItem(name: "smart_format", value: "true"))

        // Build URL with query parameters
        var urlComponents = URLComponents(string: endpoint)!
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw DeepgramError.apiError("Invalid URL", 0)
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/x-caf", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 300 // 300 seconds timeout (increased for large audio files)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DeepgramError.networkError(NSError(domain: "com.echotune", code: -1))
            }

            print("   Response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                // Try to parse error message
                if let errorResponse = try? JSONDecoder().decode(DeepgramErrorResponse.self, from: data) {
                    throw DeepgramError.apiError(errorResponse.err_msg ?? "Unknown error", httpResponse.statusCode)
                }
                throw DeepgramError.apiError("HTTP \(httpResponse.statusCode)", httpResponse.statusCode)
            }

            // Parse successful response
            let deepgramResponse = try JSONDecoder().decode(DeepgramResponse.self, from: data)

            print("✅ Deepgram transcription successful")

            return deepgramResponse

        } catch let error as DeepgramError {
            await MainActor.run {
                lastError = error
            }
            throw error
        } catch {
            let deepgramError = DeepgramError.networkError(error)
            await MainActor.run {
                lastError = deepgramError
            }
            throw deepgramError
        }
    }

    // Convenience method that returns just the transcript text
    func transcribeToText(
        audioData: Data,
        model: DeepgramModel = .nova,
        language: String? = nil,
        apiKey: String
    ) async throws -> String {
        let response = try await transcribe(
            audioData: audioData,
            model: model,
            language: language,
            apiKey: apiKey
        )

        return response.getTranscript()
    }
}

// MARK: - Response Models

struct DeepgramResponse: Codable {
    let metadata: DeepgramMetadata?
    let results: DeepgramResults

    func getTranscript() -> String {
        return results.channels.first?.alternatives.first?.transcript ?? ""
    }

    func getConfidence() -> Double? {
        return results.channels.first?.alternatives.first?.confidence
    }

    func getWords() -> [DeepgramWord]? {
        return results.channels.first?.alternatives.first?.words
    }
}

struct DeepgramMetadata: Codable {
    let transaction_key: String?
    let request_id: String?
    let sha256: String?
    let created: String?
    let duration: Double?
    let channels: Int?
}

struct DeepgramResults: Codable {
    let channels: [DeepgramChannel]
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let confidence: Double?
    let words: [DeepgramWord]?
}

struct DeepgramWord: Codable {
    let word: String
    let start: Double
    let end: Double
    let confidence: Double?
    let speaker: Int?  // For diarization
}

struct DeepgramErrorResponse: Codable {
    let err_code: String?
    let err_msg: String?
}
