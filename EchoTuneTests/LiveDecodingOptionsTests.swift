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
    }

    @Test func optionsPreserveTheLanguageHint() {
        let engine = WhisperEngine.shared

        let opts = engine.makeDecodingOptions(mode: .final, detectLanguage: false, language: "es-ES")
        #expect(opts.language == "es-ES")
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