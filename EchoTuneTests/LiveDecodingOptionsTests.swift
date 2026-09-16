//
//  LiveDecodingOptionsTests.swift
//  EchoTuneTests
//
//  Phase 2 (7.2.1) — live-tick hot path.
//
//  Verifies language pinning (P2.1) and greedy decode mode (P2.2) are
//  constructed and applied correctly, without requiring a loaded model.
//

import Foundation
import Testing
import WhisperKit
@testable import EchoTune

@MainActor
struct LiveDecodingOptionsTests {

    // MARK: - Decode mode (P2.2)

    @Test func optionsForLiveModeAreGreedy() {
        let engine = WhisperEngine.shared

        let live = engine.makeDecodingOptions(mode: .live, detectLanguage: true, language: "en")
        #expect(live.temperature == 0.0)
        #expect(live.temperatureFallbackCount == 0)
        #expect(live.detectLanguage == true)
        #expect(live.wordTimestamps == true)

        let liveNoDetect = engine.makeDecodingOptions(mode: .live, detectLanguage: false, language: "fr")
        #expect(liveNoDetect.temperature == 0.0)
        #expect(liveNoDetect.temperatureFallbackCount == 0)
        #expect(liveNoDetect.detectLanguage == false)
    }

    @Test func optionsForFinalModeReproduceWhisperKitDefaults() {
        let engine = WhisperEngine.shared

        let final = engine.makeDecodingOptions(mode: .final, detectLanguage: false, language: "en")
        // 7.1.0 used WhisperKit defaults: temp 0.0, fallback 5, skipSpecial false.
        #expect(final.temperature == 0.0)
        #expect(final.temperatureFallbackCount == 5)
        #expect(final.skipSpecialTokens == false)
        #expect(final.wordTimestamps == false)
    }

    @Test func optionsPreserveTheLanguageHint() {
        let engine = WhisperEngine.shared

        let opts = engine.makeDecodingOptions(mode: .final, detectLanguage: false, language: "es-ES")
        #expect(opts.language == "es-ES")
    }

    // MARK: - No decoder-side conditioning (7.4.7 regression)

    /// WhisperKit 0.15.0 returns an empty transcription for *every* decode when
    /// `promptTokens` is non-nil with the local CoreML Whisper models. EchoTune
    /// used to pass the user's vocabulary (which always contained "EchoTune")
    /// on every decode, so all local transcription came back blank. Guard the
    /// decoder against ever being fed conditioning tokens again.
    @Test func optionsNeverCarryDecoderConditioning() {
        let engine = WhisperEngine.shared

        for mode in [WhisperEngine.DecodeMode.live, .final] {
            let opts = engine.makeDecodingOptions(mode: mode, detectLanguage: true, language: "en")
            #expect(opts.promptTokens == nil)
            #expect(opts.prefixTokens == nil)
        }
    }

    // MARK: - Language detection pinning (P2.1)

    @Test func detectLanguageIsRequestedWhenPinIsNil() {
        let engine = WhisperEngine.shared
        engine.sessionDetectedLanguage = nil

        #expect(engine.liveTickDetectLanguage == true)
        #expect(engine.finalTailDetectLanguage == true)
    }

    @Test func pinnedSessionSkipsDetectionOnTicks() {
        let engine = WhisperEngine.shared
        engine.sessionDetectedLanguage = "en"
        // Ensure translate-to-English is off so it doesn't force tail detection.
        let originalTranslate = AppSettings.shared.translateToEnglish
        AppSettings.shared.translateToEnglish = false
        defer { AppSettings.shared.translateToEnglish = originalTranslate }

        #expect(engine.liveTickDetectLanguage == false)
        // Tail also skips detection when pinned and translate is off.
        #expect(engine.finalTailDetectLanguage == false)
    }

    @Test func translateToEnglishKeepsTailDetection() {
        let engine = WhisperEngine.shared
        engine.sessionDetectedLanguage = "en"

        let originalTranslate = AppSettings.shared.translateToEnglish
        AppSettings.shared.translateToEnglish = true
        defer { AppSettings.shared.translateToEnglish = originalTranslate }

        #expect(engine.liveTickDetectLanguage == false)
        // Even with a pin, translate-to-English forces re-detection on the
        // final tail so the translation pass uses the true language.
        #expect(engine.finalTailDetectLanguage == true)
    }

    @Test func resetSessionLanguageClearsThePin() {
        let engine = WhisperEngine.shared

        engine.sessionDetectedLanguage = "fr"
        #expect(engine.sessionDetectedLanguage == "fr")

        engine.resetSessionLanguage()
        #expect(engine.sessionDetectedLanguage == nil)
    }
}

@MainActor
struct LanguageDefaultTests {
    @Test func fixedLanguageAppliesOnceAndRespectsOverride() {
        let settings = AppSettings.shared
        let modelID = "test-paraformer-language"
        let previousLanguage = settings.preferredLanguage
        let previousModel = UserDefaults.standard.string(forKey: "defaultTranscriptionModel")
        defer {
            settings.preferredLanguage = previousLanguage
            if let previousModel { UserDefaults.standard.set(previousModel, forKey: "defaultTranscriptionModel") }
            else { UserDefaults.standard.removeObject(forKey: "defaultTranscriptionModel") }
            UserDefaults.standard.removeObject(forKey: "languageOverriddenFor_\(modelID)")
        }

        UserDefaults.standard.set(modelID, forKey: "defaultTranscriptionModel")
        UserDefaults.standard.removeObject(forKey: "languageOverriddenFor_\(modelID)")
        settings.preferredLanguage = "en-US"
        UserDefaults.standard.removeObject(forKey: "languageOverriddenFor_\(modelID)")
        settings.applyModelLanguageDefault("zh-CN", modelID: modelID)
        #expect(settings.preferredLanguage == "zh-CN")

        UserDefaults.standard.set(true, forKey: "languageOverriddenFor_\(modelID)")
        settings.preferredLanguage = "fr-FR"
        settings.applyModelLanguageDefault("zh-CN", modelID: modelID)
        #expect(settings.preferredLanguage == "fr-FR")
    }
}

struct SenseVoicePostprocessorTests {
    @Test func stripsObservedSenseVoiceTagsAndCollapsesWhitespace() {
        let result = SenseVoicePostprocessor.clean("<|zh|><|NEUTRAL|>你好 [BGM] 世界 [Laughter]。")
        #expect(result.text == "你好 世界 。")
        #expect(result.removedTags == ["<|zh|>", "<|NEUTRAL|>", "[BGM]", "[Laughter]"])
    }

    @Test func stripsTagsAdjacentToPunctuationAndTagOnlyInput() {
        let punctuation = SenseVoicePostprocessor.clean("[Cough]你好，[Applause]世界。")
        #expect(punctuation.text == "你好， 世界。")
        let empty = SenseVoicePostprocessor.clean("<|Music|>[BGM]")
        #expect(empty.text.isEmpty)
        #expect(empty.removedTags == ["<|Music|>", "[BGM]"])
    }

    @Test func keepTagsIsAnExplicitDebugEscapeHatch() {
        let result = SenseVoicePostprocessor.clean(" <|ja|> 来週 [Music] ", keepTags: true)
        #expect(result.text == "<|ja|> 来週 [Music]")
        #expect(result.removedTags.isEmpty)
    }
}