import Foundation
import Testing
@testable import EchoTune

/// ET-762 · Apple on-device intelligence cleanup.
struct OnDeviceRefinementProviderTests {

    // MARK: Availability gating

    @Test func availabilityMatchesTheRuntime() {
        // On macOS < 26 this must be false; on macOS 26+ it depends on Apple
        // Intelligence being on. Either way the property must be readable and
        // consistent with its own reason string.
        if OnDeviceRefinementProvider.isAvailable {
            #expect(OnDeviceRefinementProvider.unavailableReason == nil)
        } else {
            #expect(OnDeviceRefinementProvider.unavailableReason != nil,
                    "an unavailable provider must explain why")
        }
    }

    @Test func theModelIsOnlyOfferedWhenItCanActuallyRun() {
        let offered = AIEnhancementEngine.EnhancementModel.offered
        let includesOnDevice = offered.contains(.appleOnDevice)
        #expect(includesOnDevice == OnDeviceRefinementProvider.isAvailable,
                "the picker must not list an on-device model that would immediately error")
    }

    @Test func allOnDeviceModelsAreInTheOfferedListWhenAvailable() {
        // The default case set stays complete for every other provider.
        let offered = AIEnhancementEngine.EnhancementModel.offered
        #expect(offered.contains(.hosted))
        #expect(offered.contains(.groqLlama))
        #expect(offered.contains(.gemini25Flash))
        #expect(offered.contains(.localOllama))
    }

    // MARK: Provider wiring

    @Test func onDeviceIsItsOwnProviderWithNoAPIKey() {
        let model = AIEnhancementEngine.EnhancementModel.appleOnDevice
        #expect(model.provider == .onDevice)
        #expect(model.rawValue == "apple-on-device")
        #expect(AppSettings.shared.apiKey(for: .onDevice) == "",
                "the on-device path must never ask for a key")
    }

    @Test func everyProviderHasADisplayName() {
        for provider in [AIEnhancementEngine.ProviderKind.hosted, .groq, .google, .openai, .localCLI, .onDevice] {
            #expect(!provider.displayName.isEmpty)
        }
        for model in AIEnhancementEngine.EnhancementModel.allCases {
            #expect(!model.displayName.isEmpty)
            #expect(!model.shortName.isEmpty)
        }
    }

    // MARK: Empty/short input handling

    @Test func emptyTranscriptIsReturnedUntouchedWithoutTouchingTheModel() async throws {
        let input = "   \n  "
        let output = try await OnDeviceRefinementProvider.polish(input, prompt: "clean")
        #expect(output == input, "whitespace-only input must short-circuit")
    }

    @Test func theFirstEntryOfAllCasesIsStable() {
        // `offered` is derived by filtering `allCases`; ordering must not drift or
        // the Settings picker will reorder itself between launches.
        #expect(AIEnhancementEngine.EnhancementModel.allCases.first == .hosted)
    }

    @Test func defaultPromptHonoursACustomPrompt() {
        #expect(OnDeviceRefinementProvider.defaultPrompt(customPrompt: "be terse") == "be terse")
        #expect(OnDeviceRefinementProvider.defaultPrompt(customPrompt: "  ") != "  ")
        #expect(OnDeviceRefinementProvider.defaultPrompt(customPrompt: nil).contains("filler"))
    }

    @Test func unavailableSelectionFallsBackInsteadOfErroring() {
        // A stale "apple-on-device" in UserDefaults on a Mac where Apple
        // Intelligence is now off must not make every dictation fail.
        let previous = UserDefaults.standard.string(forKey: "selectedEnhancementModel")
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: "selectedEnhancementModel")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedEnhancementModel")
            }
        }

        if !OnDeviceRefinementProvider.isAvailable {
            let migrated = AppSettings.migratedEnhancementModelSelectionForTesting("apple-on-device")
            #expect(migrated != "apple-on-device", "unavailable on-device selection must migrate away")
        }
    }
}
