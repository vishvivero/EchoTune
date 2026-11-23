//
//  OnDeviceRefinementProvider.swift
//  EchoTune
//
//  ET-762 · Apple's on-device Foundation Models as an enhancement provider.
//
//  WHY THIS EXISTS
//  ---------------
//  Every other enhancement path leaves the Mac: the hosted proxy, Groq, Gemini,
//  OpenAI and even Ollama (localhost, but still a service to install). On
//  macOS 26+ Apple ships a small on-device model with a first-party API
//  (`FoundationModels`), which means:
//
//    · zero network calls for a feature that sends your words somewhere by default
//    · nothing to download, no server to run, no API key to paste
//
//  The framework does not exist on older SDKs, so the whole file is gated. On
//  macOS 26+ the model is additionally gated behind a runtime availability check,
//  because it can be unavailable (device not supported, Apple Intelligence off).
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Bridges Apple's on-device model into EchoTune's enhancement pipeline.
///
/// Usage mirrors `LocalCLIEnhancementProvider`: hand it a transcript and the
/// shared enhancement prompt, get polished text back or a typed error.
enum OnDeviceRefinementProvider {

    enum ProviderError: Error, LocalizedError {
        case unsupportedOS
        case modelUnavailable(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .unsupportedOS:
                return "Apple Intelligence cleanup needs macOS 26 or later."
            case .modelUnavailable(let detail):
                return "The on-device model is not available: \(detail)"
            case .emptyResponse:
                return "The on-device model returned nothing. Using the original text."
            }
        }
    }

    /// True when this build was compiled against the FoundationModels framework.
    static var isCompiledIn: Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }

    /// True when the on-device model can actually run right now.
    /// Never true on a build that lacks the framework, so callers can gate a
    /// settings row on this single property.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            default:
                return false
            }
        }
        return false
        #else
        return false
        #endif
    }

    /// Human-readable reason the on-device model is unavailable, for the
    /// settings row. `nil` when it is available.
    static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "This Mac is not eligible for Apple Intelligence."
                case .appleIntelligenceNotEnabled:
                    return "Turn on Apple Intelligence in System Settings."
                case .modelNotReady:
                    return "The on-device model is still preparing. Try again shortly."
                @unknown default:
                    return "The on-device model is unavailable."
                }
            @unknown default:
                return "The on-device model is unavailable."
            }
        }
        return "Apple Intelligence cleanup needs macOS 26 or later."
        #else
        return "This build was compiled without the FoundationModels framework."
        #endif
    }

    /// Polishes `transcript` entirely on-device.
    ///
    /// - Parameters:
    ///   - transcript: the raw or partially processed dictation.
    ///   - prompt: the same enhancement prompt every other provider receives,
    ///     so switching providers does not change the shape of the output.
    /// - Returns: the polished text, unchanged if the model produced nothing.
    static func polish(_ transcript: String, prompt: String) async throws -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return transcript }

        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else { throw ProviderError.unsupportedOS }

        guard case .available = SystemLanguageModel.default.availability else {
            throw ProviderError.modelUnavailable(unavailableReason ?? "unknown")
        }

        let session = LanguageModelSession(instructions: prompt)
        let response = try await session.respond(to: trimmed)
        let output = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { throw ProviderError.emptyResponse }
        return output
        #else
        throw ProviderError.unsupportedOS
        #endif
    }

    /// The prompt every provider shares, exposed so the on-device path can be
    /// exercised without an `AIEnhancementEngine` instance (which is a singleton
    /// that owns network clients).
    static func defaultPrompt(customPrompt: String?) -> String {
        if let customPrompt, !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customPrompt
        }
        return """
        You clean up dictated speech. Rules:
        - Fix grammar, spelling and punctuation.
        - Remove filler words (uh, um, erm).
        - Preserve the speaker's meaning, tone and vocabulary.
        - Do not add, explain or summarise anything.
        - Reply with the cleaned text only, no preamble, no quotation marks.
        """
    }
}