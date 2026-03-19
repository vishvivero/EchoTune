//
//  MeetingSummaryEngine.swift
//  EchoTune
//
//  Generates AI summaries from meeting transcripts.
//

import Foundation

class MeetingSummaryEngine {

    static let shared = MeetingSummaryEngine()

    /// Generate a structured meeting summary from the transcript.
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

        // Use Groq for fast summary generation (or fallback to configured AI enhancement model)
        let apiKey = AppSettings.shared.groqAPIKey
        guard !apiKey.isEmpty else {
            debugLog("⚠️ MeetingSummaryEngine: No Groq API key, falling back to basic extraction")
            let basicResult = extractBasicSummary(from: transcript)
            completion(.success(basicResult))
            return
        }

        callGroqAPI(prompt: prompt, apiKey: apiKey, completion: completion)
    }

    // MARK: - Prompt Builder

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
            prompt += "\nUser's own notes during the meeting:\n\(userNotes)\n"
        }

        prompt += "\nMeeting Transcript:\n\(transcript)"

        return prompt
    }

    // MARK: - Groq API Call

    private func callGroqAPI(prompt: String, apiKey: String, completion: @escaping (Result<MeetingSummaryResult, Error>) -> Void) {
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            completion(.failure(SummaryError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Truncate transcript if too long (Groq context limit)
        let maxTranscriptLength = 28000  // Leave room for prompt + response
        let truncatedPrompt: String
        if prompt.count > maxTranscriptLength {
            truncatedPrompt = String(prompt.prefix(maxTranscriptLength)) + "\n\n[Transcript truncated due to length]"
        } else {
            truncatedPrompt = prompt
        }

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "user", "content": truncatedPrompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2000,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                debugLog("❌ MeetingSummaryEngine: API error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(SummaryError.noResponse))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let choices = json?["choices"] as? [[String: Any]]
                let message = choices?.first?["message"] as? [String: Any]
                let content = message?["content"] as? String ?? ""

                debugLog("🧠 MeetingSummaryEngine: Got response (\(content.count) chars)")

                // Parse the JSON response
                guard let responseData = content.data(using: .utf8),
                      let parsed = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                    debugLog("⚠️ MeetingSummaryEngine: Failed to parse JSON, extracting basic summary")
                    let basic = self.extractBasicSummary(from: content)
                    completion(.success(basic))
                    return
                }

                let result = MeetingSummaryResult(
                    title: parsed["title"] as? String ?? "Untitled Meeting",
                    summary: parsed["summary"] as? String ?? "",
                    actionItems: parsed["actionItems"] as? [String] ?? [],
                    decisions: parsed["decisions"] as? [String] ?? [],
                    keyPoints: parsed["keyPoints"] as? [String] ?? [],
                    participants: parsed["participants"] as? [String] ?? []
                )

                debugLog("✅ MeetingSummaryEngine: Summary generated - \(result.actionItems.count) action items, \(result.decisions.count) decisions")
                completion(.success(result))

            } catch {
                debugLog("❌ MeetingSummaryEngine: Parse error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Basic Extraction Fallback

    private func extractBasicSummary(from transcript: String) -> MeetingSummaryResult {
        // Simple heuristic extraction when no API is available
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

// MARK: - Models

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
