//
//  AIEnhancementEngine+Providers.swift
//  EchoTune
//
//  Provider-specific API methods extracted from AIEnhancementEngine.
//  Contains Gemini, OpenAI, and Groq enhancement implementations.
//

import Foundation

extension AIEnhancementEngine {

    // MARK: - Gemini Enhancement

    func enhanceWithGemini(_ transcript: String,
                           model: EnhancementModel,
                           apiKey: String,
                           customPrompt: String?,
                           dictionaryContext: String?,
                           screenContext: String? = nil) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent"

        let systemPrompt = buildEnhancementPrompt(customPrompt: customPrompt, dictionaryContext: dictionaryContext, screenContext: screenContext)

        let requestBody: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "<DICTATION>\n\(transcript)\n</DICTATION>"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 4000
            ]
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw EnhancementError.apiError(message)
            }
            throw EnhancementError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw EnhancementError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OpenAI Enhancement

    func enhanceWithOpenAI(_ transcript: String,
                           model: EnhancementModel,
                           apiKey: String,
                           customPrompt: String?,
                           dictionaryContext: String?,
                           screenContext: String? = nil) async throws -> String {
        let endpoint = "https://api.openai.com/v1/chat/completions"

        let systemPrompt = buildEnhancementPrompt(customPrompt: customPrompt, dictionaryContext: dictionaryContext, screenContext: screenContext)

        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "<DICTATION>\n\(transcript)\n</DICTATION>"]
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw EnhancementError.apiError(message)
            }
            throw EnhancementError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw EnhancementError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Groq Enhancement (OpenAI-compatible API)

    func enhanceWithGroq(_ transcript: String,
                         model: EnhancementModel,
                         apiKey: String,
                         customPrompt: String?,
                         dictionaryContext: String?,
                           screenContext: String? = nil) async throws -> String {
        // Groq uses an OpenAI-compatible chat completions API
        let endpoint = "https://api.groq.com/openai/v1/chat/completions"

        let systemPrompt = buildEnhancementPrompt(customPrompt: customPrompt, dictionaryContext: dictionaryContext, screenContext: screenContext)

        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "<DICTATION>\n\(transcript)\n</DICTATION>"]
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw EnhancementError.apiError(message)
            }
            throw EnhancementError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Same response format as OpenAI
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw EnhancementError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
