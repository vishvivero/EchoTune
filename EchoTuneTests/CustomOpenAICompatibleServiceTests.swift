import Foundation
import Testing
@testable import EchoTune

/// ET-766 · custom OpenAI-compatible STT & chat endpoints.
struct CustomOpenAICompatibleServiceTests {

    // MARK: URL normalisation

    @Test func bareLocalhostGetsHTTPAndVersion() {
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("localhost:1234")?.absoluteString == "http://localhost:1234/v1")
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("127.0.0.1:8000")?.absoluteString == "http://127.0.0.1:8000/v1")
    }

    @Test func existingVersionPathIsPreserved() {
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("http://localhost:1234/v1")?.absoluteString == "http://localhost:1234/v1")
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("https://openrouter.ai/api/v1")?.absoluteString == "https://openrouter.ai/api/v1")
    }

    @Test func pastedFullEndpointIsRolledBackToItsBase() {
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("http://localhost:1234/v1/chat/completions")?.absoluteString == "http://localhost:1234/v1")
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("http://localhost:9000/v1/audio/transcriptions")?.absoluteString == "http://localhost:9000/v1")
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("http://localhost:8000/chat/completions")?.absoluteString == "http://localhost:8000/v1")
    }

    @Test func trailingSlashesAndQueryNoiseAreTrimmed() {
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("  http://localhost:1234/v1/  ")?.absoluteString == "http://localhost:1234/v1")
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("http://localhost:1234/v1?foo=bar")?.absoluteString == "http://localhost:1234/v1")
    }

    @Test func remoteHostsDefaultToHTTPS() {
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("api.example.com")?.absoluteString == "https://api.example.com/v1")
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("openrouter.ai/api/v1")?.absoluteString == "https://openrouter.ai/api/v1")
    }

    @Test func emptyOrGarbageInputIsRejected() {
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("") == nil)
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("   ") == nil)
        #expect(CustomOpenAICompatibleService.normalizedBaseURL("/v1/chat/completions") == nil)
    }

    @Test func endpointURLsAreBuiltFromTheNormalisedBase() {
        #expect(CustomOpenAICompatibleService.endpointURL(base: "localhost:1234", kind: .chat)?.absoluteString
                == "http://localhost:1234/v1/chat/completions")
        #expect(CustomOpenAICompatibleService.endpointURL(base: "localhost:8000", kind: .transcription)?.absoluteString
                == "http://localhost:8000/v1/audio/transcriptions")
    }

    // MARK: Locality / key requirement

    @Test func localEndpointsDoNotRequireAKey() {
        #expect(CustomOpenAICompatibleService.isLocalEndpoint("localhost:1234"))
        #expect(CustomOpenAICompatibleService.isLocalEndpoint("http://127.0.0.1:8000/v1"))
        #expect(CustomOpenAICompatibleService.isLocalEndpoint("http://192.168.1.40:1234"))
        #expect(CustomOpenAICompatibleService.requiresAPIKey("localhost:1234") == false)
    }

    @Test func remoteEndpointsDoRequireAKey() {
        #expect(CustomOpenAICompatibleService.isLocalEndpoint("https://openrouter.ai/api/v1") == false)
        #expect(CustomOpenAICompatibleService.requiresAPIKey("openrouter.ai/api/v1") == true)
    }

    // MARK: Requests

    @Test func transcriptionRequestIsMultipartWithModelAndLanguage() throws {
        let request = try #require(CustomOpenAICompatibleService.transcriptionRequest(
            audio: Data(repeating: 0xAB, count: 32),
            filename: "audio.wav",
            model: "whisper-1",
            language: "en",
            apiKey: nil,
            boundary: "BOUND"
        ))

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=BOUND")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil, "local server must not receive a bearer header")

        let body = try #require(request.httpBody)
        // The body contains raw binary audio, so decode leniently and check the
        // textual parts rather than assuming the whole thing is valid UTF-8.
        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains("name=\"file\"; filename=\"audio.wav\""))
        #expect(text.contains("name=\"model\""))
        #expect(text.contains("whisper-1"))
        #expect(text.contains("name=\"language\""))
        #expect(text.hasSuffix("--BOUND--\r\n"))
    }

    @Test func emptyAudioProducesNoRequest() {
        #expect(CustomOpenAICompatibleService.transcriptionRequest(
            audio: Data(), filename: "audio.wav", model: "whisper-1", language: nil, apiKey: nil
        ) == nil)
    }

    @Test func chatRequestCarriesMessagesAndModel() throws {
        let built = try #require(CustomOpenAICompatibleService.chatRequest(
            messages: [("system", "clean up"), ("user", "hello there")],
            model: "local-model",
            apiKey: "sk-remote"
        ))

        let object = try #require(try JSONSerialization.jsonObject(with: built.body) as? [String: Any])
        #expect(object["model"] as? String == "local-model")
        let messages = try #require(object["messages"] as? [[String: String]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[1]["content"] == "hello there")
    }

    @Test func chatRequestRejectsEmptyInput() {
        #expect(CustomOpenAICompatibleService.chatRequest(messages: [], model: "m", apiKey: nil) == nil)
        #expect(CustomOpenAICompatibleService.chatRequest(messages: [("user", "hi")], model: "", apiKey: nil) == nil)
    }

    @Test func authorizationIsOnlyAppliedWhenAKeyExists() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        CustomOpenAICompatibleService.applyAuthorization("", to: &request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        CustomOpenAICompatibleService.applyAuthorization("sk-1", to: &request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-1")
    }

    // MARK: Responses

    @Test func transcriptionTextIsExtracted() {
        let simple = Data(#"{"text":"hello world"}"#.utf8)
        #expect(CustomOpenAICompatibleService.transcriptionText(from: simple) == "hello world")

        let verbose = Data(#"{"task":"transcribe","segments":[],"text":"from segments"}"#.utf8)
        #expect(CustomOpenAICompatibleService.transcriptionText(from: verbose) == "from segments")

        #expect(CustomOpenAICompatibleService.transcriptionText(from: Data(#"{"text":"   "}"#.utf8)) == nil)
        #expect(CustomOpenAICompatibleService.transcriptionText(from: Data("not json".utf8)) == nil)
    }

    @Test func chatTextIsExtractedFromChoices() {
        let data = Data(#"{"choices":[{"message":{"role":"assistant","content":" cleaned "}}]}"#.utf8)
        #expect(CustomOpenAICompatibleService.chatText(from: data) == "cleaned")
        #expect(CustomOpenAICompatibleService.chatText(from: Data(#"{"choices":[]}"#.utf8)) == nil)
        #expect(CustomOpenAICompatibleService.chatText(from: Data("{}".utf8)) == nil)
    }

    // MARK: Presets

    @Test func presetsAllNormaliseToUsableURLs() {
        for preset in CustomOpenAICompatibleService.Preset.all {
            let url = CustomOpenAICompatibleService.normalizedBaseURL(preset.baseURL)
            #expect(url != nil, "\(preset.name) preset must produce a valid URL")
            #expect(url?.absoluteString.hasSuffix("/v1") == true, "\(preset.name) must end in /v1")
        }
    }
}
