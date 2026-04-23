//
//  MeetingSummaryEngine.swift
//  EchoTune
//
//  Generates AI summaries from meeting transcripts using the simplified
//  Groq-first / Gemini-secondary provider strategy.
//

import Foundation

class MeetingSummaryEngine {

    static let shared = MeetingSummaryEngine()

    func generateSummary(
        transcript: String,
        template: MeetingTemplate,
        userNotes: String = "",
        completion: @escaping (Result<MeetingSummaryResult, Error>) -> Void
    ) {
        guard !transcript.isEmpty else {
            completion(.failure(SummaryError.emptyTranscript))
            return
        }

        debugLog("🧠 MeetingSummaryEngine: Generating summary (template: \(template.rawValue), transcript: \(transcript.count) chars)")

        let prompt = buildPrompt(transcript: transcript, template: template, userNotes: userNotes)

        guard let (model, apiKey) = preferredSummaryModel() else {
            debugLog("⚠️ MeetingSummaryEngine: No Groq/Gemini API key, falling back to basic extraction")
            completion(.success(extractBasicSummary(from: transcript)))
            return
        }

        callProvider(model: model, prompt: prompt, apiKey: apiKey, transcript: transcript, completion: completion)
    }

    private func preferredSummaryModel() -> (AIEnhancementEngine.EnhancementModel, String)? {
        let settings = AppSettings.shared

        if let selected = AIEnhancementEngine.EnhancementModel(rawValue: settings.selectedEnhancementModel) {
            let key = settings.apiKey(for: selected.provider)
            if !key.isEmpty {
                return (selected, key)
            }
        }

        if !settings.groqAPIKey.isEmpty {
            return (.groqLlama, settings.groqAPIKey)
        }

        if !settings.geminiAPIKey.isEmpty {
            return (.gemini25Flash, settings.geminiAPIKey)
        }

        return nil
    }

    private func buildPrompt(transcript: String, template: MeetingTemplate, userNotes: String) -> String {
        var prompt = """
        You are a meeting notes assistant. Analyse the following meeting transcript and generate structured notes.

        \(template.summaryPromptContext)

        Output EXACTLY this JSON format (no markdown, no code fences):
        {
            "title": "Brief meeting title (infer from content)",
            "summary": "2-3 sentence overview of the meeting",
            "actionItems": ["Action item 1", "Action item 2"],
            "decisions": ["Decision 1", "Decision 2"],
            "keyPoints": ["Key point 1", "Key point 2"],
            "participants": ["Name 1", "Name 2"]
        }

        Rules:
        - Infer participant names from the transcript if possible
        - Action items should be specific and assignable
        - Decisions should be clear and final
        - Key points should capture the most important information
        - If a field has no content, use an empty array []
        - Title should be concise (5-8 words max)
        """

        if !userNotes.isEmpty {
            prompt += "\n\nUser's own notes during the meeting:\n\(userNotes)\n"
        }

        prompt += "\n\nMeeting Transcript:\n\(transcript)"
        return prompt
    }

    private func callProvider(
        model: AIEnhancementEngine.EnhancementModel,
        prompt: String,
        apiKey: String,
        transcript: String,
        completion: @escaping (Result<MeetingSummaryResult, Error>) -> Void
    ) {
        switch model.provider {
        case .groq:
            callGroqAPI(prompt: prompt, apiKey: apiKey, model: model, transcript: transcript, completion: completion)
        case .google:
            callGeminiAPI(prompt: prompt, apiKey: apiKey, model: model, transcript: transcript, completion: completion)
        }
    }

    private func callGroqAPI(
        prompt: String,
        apiKey: String,
        model: AIEnhancementEngine.EnhancementModel,
        transcript: String,
        completion: @escaping (Result<MeetingSummaryResult, Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            completion(.failure(SummaryError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let maxPromptLength = 28000
        let truncatedPrompt = prompt.count > maxPromptLength
            ? String(prompt.prefix(maxPromptLength)) + "\n\n[Transcript truncated due to length]"
            : prompt

        let body: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                ["role": "user", "content": truncatedPrompt]
            ],
            "temperature": 0.2,
            "max_tokens": 2000,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                debugLog("❌ MeetingSummaryEngine: Groq API error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(SummaryError.noResponse))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let choices = json?["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: Any]
                let content = message?["content"] as? String ?? ""
                completion(.success(self.parseSummaryPayload(content, fallbackTranscript: transcript)))
            } catch {
                debugLog("❌ MeetingSummaryEngine: Groq parse error: \(error)")
                completion(.success(self.extractBasicSummary(from: transcript)))
            }
        }.resume()
    }

    private func callGeminiAPI(
        prompt: String,
        apiKey: String,
        model: AIEnhancementEngine.EnhancementModel,
        transcript: String,
        completion: @escaping (Result<MeetingSummaryResult, Error>) -> Void
    ) {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent") else {
            completion(.failure(SummaryError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let requestBody: [String: Any] = [
            "systemInstruction": [
                "parts": [[
                    "text": "You are a meeting notes assistant. Always return strict JSON matching the schema requested by the user."
                ]]
            ],
            "contents": [[
                "role": "user",
                "parts": [["text": prompt]]
            ]],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 2000,
                "responseMimeType": "application/json"
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                debugLog("❌ MeetingSummaryEngine: Gemini API error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(SummaryError.noResponse))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let candidates = json?["candidates"] as? [[String: Any]]
                let content = candidates?.first?["content"] as? [String: Any]
                let parts = content?["parts"] as? [[String: Any]]
                let text = parts?.first?["text"] as? String ?? ""
                completion(.success(self.parseSummaryPayload(text, fallbackTranscript: transcript)))
            } catch {
                debugLog("❌ MeetingSummaryEngine: Gemini parse error: \(error)")
                completion(.success(self.extractBasicSummary(from: transcript)))
            }
        }.resume()
    }

    private func parseSummaryPayload(_ content: String, fallbackTranscript: String) -> MeetingSummaryResult {
        guard let responseData = content.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            debugLog("⚠️ MeetingSummaryEngine: Failed to parse JSON payload, using basic extraction")
            return extractBasicSummary(from: fallbackTranscript)
        }

        return MeetingSummaryResult(
            title: parsed["title"] as? String ?? "Untitled Meeting",
            summary: parsed["summary"] as? String ?? "",
            actionItems: parsed["actionItems"] as? [String] ?? [],
            decisions: parsed["decisions"] as? [String] ?? [],
            keyPoints: parsed["keyPoints"] as? [String] ?? [],
            participants: parsed["participants"] as? [String] ?? []
        )
    }

    private func extractBasicSummary(from transcript: String) -> MeetingSummaryResult {
        let sentences = transcript.components(separatedBy: ". ")
        let keyPoints = Array(sentences.prefix(5)).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return MeetingSummaryResult(
            title: "Meeting Notes",
            summary: String(transcript.prefix(200)),
            actionItems: [],
            decisions: [],
            keyPoints: keyPoints,
            participants: []
        )
    }
}

struct MeetingSummaryResult {
    let title: String
    let summary: String
    let actionItems: [String]
    let decisions: [String]
    let keyPoints: [String]
    let participants: [String]
}

enum SummaryError: LocalizedError {
    case emptyTranscript
    case invalidURL
    case noResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .emptyTranscript: return "No transcript content to summarise"
        case .invalidURL: return "Invalid API URL"
        case .noResponse: return "No response from AI service"
        case .parseError: return "Failed to parse summary response"
        }
    }
}
