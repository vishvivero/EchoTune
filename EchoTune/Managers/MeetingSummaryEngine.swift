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

        if !settings.openaiAPIKey.isEmpty {
            return (.openAIGPT55, settings.openaiAPIKey)
        }

        return nil
    }

    /// Truncate text over `limit` chars by keeping the FIRST and LAST halves, so both
    /// the meeting intro and the wrap-up (where action items usually live) survive.
    private func middleTruncated(_ text: String, limit: Int = 28000) -> String {
        guard text.count > limit else { return text }
        let keep = limit / 2
        let head = String(text.prefix(keep))
        let tail = String(text.suffix(keep))
        return head + "\n...\n" + tail
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

        prompt += "\n\nMeeting Transcript:\n\(middleTruncated(transcript, limit: 28000))"
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
        case .openai:
            callOpenAIAPI(prompt: prompt, apiKey: apiKey, model: model, transcript: transcript, completion: completion)
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

        // Safety net only — the transcript is already middle-truncated in buildPrompt,
        // so keep first/last halves rather than cutting off the end of the prompt.
        let truncatedPrompt = middleTruncated(prompt, limit: 30000)

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

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                debugLog("❌ MeetingSummaryEngine: Groq API error: \(error)")
                completion(.failure(error))
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                debugLog("❌ MeetingSummaryEngine: Groq HTTP \(http.statusCode)")
                completion(.failure(SummaryError.httpError(http.statusCode)))
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
                if let summary = self.parseSummaryPayload(content) {
                    completion(.success(summary))
                } else {
                    debugLog("❌ MeetingSummaryEngine: Groq returned no usable summary payload")
                    completion(.failure(SummaryError.parseError))
                }
            } catch {
                debugLog("❌ MeetingSummaryEngine: Groq parse error: \(error)")
                completion(.failure(SummaryError.parseError))
            }
        }.resume()
    }

    private func callOpenAIAPI(
        prompt: String,
        apiKey: String,
        model: AIEnhancementEngine.EnhancementModel,
        transcript: String,
        completion: @escaping (Result<MeetingSummaryResult, Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(SummaryError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Safety net only — the transcript is already middle-truncated in buildPrompt,
        // so keep first/last halves rather than cutting off the end of the prompt.
        let truncatedPrompt = middleTruncated(prompt, limit: 30000)

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

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                debugLog("❌ MeetingSummaryEngine: OpenAI API error: \(error)")
                completion(.failure(error))
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                debugLog("❌ MeetingSummaryEngine: OpenAI HTTP \(http.statusCode)")
                completion(.failure(SummaryError.httpError(http.statusCode)))
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
                if let summary = self.parseSummaryPayload(content) {
                    completion(.success(summary))
                } else {
                    debugLog("❌ MeetingSummaryEngine: OpenAI returned no usable summary payload")
                    completion(.failure(SummaryError.parseError))
                }
            } catch {
                debugLog("❌ MeetingSummaryEngine: OpenAI parse error: \(error)")
                completion(.failure(SummaryError.parseError))
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

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                debugLog("❌ MeetingSummaryEngine: Gemini API error: \(error)")
                completion(.failure(error))
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                debugLog("❌ MeetingSummaryEngine: Gemini HTTP \(http.statusCode)")
                completion(.failure(SummaryError.httpError(http.statusCode)))
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
                if let summary = self.parseSummaryPayload(text) {
                    completion(.success(summary))
                } else {
                    debugLog("❌ MeetingSummaryEngine: Gemini returned no usable summary payload")
                    completion(.failure(SummaryError.parseError))
                }
            } catch {
                debugLog("❌ MeetingSummaryEngine: Gemini parse error: \(error)")
                completion(.failure(SummaryError.parseError))
            }
        }.resume()
    }

    /// nil = the provider's payload was empty or not the expected JSON — the
    /// caller must report a failure, never dress a junk payload up as success.
    private func parseSummaryPayload(_ content: String) -> MeetingSummaryResult? {
        guard !content.isEmpty,
              let responseData = content.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return nil
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
            participants: [],
            isDegraded: true
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
    /// True when this is the no-API-key basic text extract, not a real AI summary.
    var isDegraded: Bool = false
}

enum SummaryError: LocalizedError {
    case emptyTranscript
    case invalidURL
    case noResponse
    case parseError
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .emptyTranscript: return "No transcript content to summarise."
        case .invalidURL: return "Invalid API URL."
        case .noResponse: return "No response from the AI service."
        case .parseError: return "The AI service returned an unreadable response."
        case .httpError(let code):
            if code == 401 || code == 403 {
                return "The AI service rejected the request (HTTP \(code)) — check your API key."
            }
            if code == 429 {
                return "The AI service is rate-limiting requests (HTTP 429) — try again shortly."
            }
            return "The AI service returned HTTP \(code)."
        }
    }
}
