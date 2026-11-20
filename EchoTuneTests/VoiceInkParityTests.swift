import AppKit
import Foundation
import Testing
@testable import EchoTune

@MainActor
struct VoiceInkParityTests {

    @Test func phoneticMatcherCorrectsMisheardProperNounsAndMultiWordSpans() {
        let matcher = PhoneticVocabularyMatcher(terms: ["EchoTune", "WhisperKit", "Kubernetes"])

        // Multi-word split span -> joined proper noun
        #expect(matcher.apply(to: "Open echo tune now.") == "Open EchoTune now.")
        #expect(matcher.apply(to: "Built with whisper kit locally.") == "Built with WhisperKit locally.")

        // Phonetic confusion
        #expect(matcher.apply(to: "Check ekotune settings.") == "Check EchoTune settings.")
        #expect(matcher.apply(to: "Deploy to kubernetis cluster.") == "Deploy to Kubernetes cluster.")

        // Common English prose must remain untouched
        let prose = "People around the world think about other things every morning."
        #expect(matcher.apply(to: prose) == prose)
    }

    @Test func fillerWordRemovalRepairsPunctuationAndSentenceCase() {
        let cleaned1 = FillerWordManager.shared.clean("Um, hello world.")
        #expect(cleaned1 == "Hello world.")

        let cleaned2 = FillerWordManager.shared.clean("I went, uh, to the store. Erm, yes!")
        #expect(cleaned2 == "I went to the store. Yes!")
    }

    @Test func smartPunctuationAdjustsMidSentenceCaseSpacingAndPeriods() {
        // Mid-sentence where `after` already has a leading space -> no duplicate trailing space!
        let ctxMidSpaced = SmartPunctuation.CursorContext(before: "I think that ", after: " works great.")
        #expect(SmartPunctuation.adjust("This feature.", context: ctxMidSpaced) == "this feature")
        #expect(SmartPunctuation.adjust("I agree.", context: ctxMidSpaced) == "I agree")

        // Mid-sentence right before another word -> appends single trailing space
        let ctxMidTightRight = SmartPunctuation.CursorContext(before: "I think that ", after: "works great.")
        #expect(SmartPunctuation.adjust("This feature.", context: ctxMidTightRight) == "this feature ")

        // Adds leading space when cursor sits directly after a word
        let ctxTight = SmartPunctuation.CursorContext(before: "Hello", after: "")
        #expect(SmartPunctuation.adjust("World.", context: ctxTight) == " world.")

        // Keeps sentence-start uppercase after period
        let ctxNewSentence = SmartPunctuation.CursorContext(before: "Done. ", after: "")
        #expect(SmartPunctuation.adjust("Next step.", context: ctxNewSentence) == "Next step.")
    }

    @Test func expandedBrowserInspectorRecognizesDiaCometFirefoxAndZen() {
        #expect(ActiveBrowserInspector.isBrowser("company.thebrowser.dia"))
        #expect(ActiveBrowserInspector.isBrowser("ai.perplexity.comet"))
        #expect(ActiveBrowserInspector.isBrowser("org.mozilla.firefox"))
        #expect(ActiveBrowserInspector.isBrowser("app.zen-browser.zen"))
        #expect(ActiveBrowserInspector.normalizedURL(from: "github.com/vishvivero/EchoTune")?.absoluteString == "https://github.com/vishvivero/EchoTune")
    }

    @Test func customOpenAIEndpointNormalizesV1SuffixWithoutDuplication() {
        let u1 = CustomOpenAICompatibleService.normalizedEndpoint(baseURL: "http://localhost:1234/v1", suffix: "/v1/chat/completions")
        #expect(u1?.absoluteString == "http://localhost:1234/v1/chat/completions")

        let u2 = CustomOpenAICompatibleService.normalizedEndpoint(baseURL: "https://openrouter.ai/api/v1/", suffix: "/v1/chat/completions")
        #expect(u2?.absoluteString == "https://openrouter.ai/api/v1/chat/completions")

        let u3 = CustomOpenAICompatibleService.normalizedEndpoint(baseURL: "localhost:8080", suffix: "/v1/audio/transcriptions")
        #expect(u3?.absoluteString == "http://localhost:8080/v1/audio/transcriptions")
    }

    @Test func configurationBackupAndCSVExportRoundTripCleanly() throws {
        let backupData = try ConfigurationBackupManager.exportBackupData()
        #expect(!backupData.isEmpty)

        let sampleItem = TranscriptionHistoryItem(
            text: "Hello, \"EchoTune\" world\nLine two",
            duration: 3.5,
            originalText: "Hello EchoTune world",
            rawTranscriptionText: "hello echotune world"
        )
        let csv = ConfigurationBackupManager.buildHistoryCSV(items: [sampleItem])
        #expect(csv.contains("\"Hello, \"\"EchoTune\"\" world\nLine two\""))
    }

    @Test func notchRecorderAndPasteMethodsAreAvailable() {
        #expect(RecorderStyle.userFacingOptions.contains(.notch))
        #expect(PasteMethod.allCases.count == 4)
    }
}
