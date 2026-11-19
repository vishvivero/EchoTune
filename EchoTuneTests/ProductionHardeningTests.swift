import Foundation
import Testing
@testable import EchoTune

@MainActor
struct ProductionHardeningTests {

    @Test func canonicalPurchaseURLPointsToEchoTuneBuy() {
        #expect(LicenseManager.purchaseURLString == "https://echotune.app/buy")
    }

    @Test func referralBackendIsDisabledWhenUnconfigured() {
        let saved = UserDefaults.standard.string(forKey: "supabaseAnonKey")
        UserDefaults.standard.removeObject(forKey: "supabaseAnonKey")
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: "supabaseAnonKey")
            }
        }
        #expect(ReferralManager.shared.isConfigured == false)
    }

    @Test func recordingSessionFreezesWhisperFallbackToAppleSpeech() {
        let whisperModel = AIModel(
            id: "openai_whisper-small.en",
            name: "Small (English)",
            size: 244_000_000,
            description: "Local Whisper model",
            language: "English",
            url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
            type: .fast,
            category: .local,
            speedRating: 4,
            accuracyRating: 4,
            isBuiltIn: false,
            backend: .whisper
        )

        let fallbackSession = RecordingSession(model: whisperModel, useLocalWhisper: false)
        #expect(fallbackSession.kind == RecordingEngineKind.appleSpeech)

        let installedSession = RecordingSession(model: whisperModel, useLocalWhisper: true)
        #expect(installedSession.kind == RecordingEngineKind.whisper)
    }

    @Test func licenseInfoBackwardsCompatibleWithoutActivationId() throws {
        let json = """
        {
          "key": "ET-TEST-1234-5678",
          "tier": "Individual",
          "activatedOn": "2026-11-01T12:00:00Z",
          "deviceFingerprint": "TEST-UUID"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LicenseInfo.self, from: Data(json.utf8))
        #expect(decoded.key == "ET-TEST-1234-5678")
        #expect(decoded.tier == .individual)
        #expect(decoded.activationId == nil)
        #expect(decoded.isValid == true)
    }

    @Test func releaseUnifiedLogsNeverContainRawTranscriptBodies() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let targets = [
            "EchoTune/AppCoordinator+Recording.swift",
            "EchoTune/AppCoordinator+Transcription.swift",
            "EchoTune/Managers/WhisperEngine+FinalResult.swift",
            "EchoTune/Managers/WhisperEngine+Streaming.swift"
        ]

        for relative in targets {
            let fileURL = repoRoot.appendingPathComponent(relative)
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            for line in contents.components(separatedBy: .newlines) where line.contains("os_log(") {
                #expect(!line.contains("transcribedText)"))
                #expect(!line.contains("payload.outputText,"))
                #expect(!line.contains("finalResult.outputText)"))
                #expect(!line.contains("tailText)"))
            }
        }
    }

    @Test func textInsertionNeverUsesForceCastToAXUIElement() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent("EchoTune/Managers/TextInsertionManager.swift")
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!contents.contains("as! AXUIElement"))
    }
}
