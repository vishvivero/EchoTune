//
//  OnDeviceRefinementProvider.swift
//  EchoTune
//
//  100% offline, zero-download, zero-key AI refinement powered by Apple's
//  built-in on-device Neural Engine language model (FoundationModels on macOS 26+).
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class OnDeviceRefinementProvider: @unchecked Sendable {
    static let shared = OnDeviceRefinementProvider()

    enum ProviderError: Error, LocalizedError {
        case unsupportedOS
        case modelUnavailable(String)
        case emptyOutput

        var errorDescription: String? {
            switch self {
            case .unsupportedOS:
                return "Apple On-Device Intelligence requires macOS 26 or later on Apple Silicon."
            case .modelUnavailable(let detail):
                return "Apple On-Device Intelligence is not ready: \(detail)"
            case .emptyOutput:
                return "On-device model returned empty text."
            }
        }
    }

    private init() {}

    var isSupportedAndAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            default:
                return false
            }
        }
        #endif
        return false
    }

    func polish(_ transcript: String, instructions: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                throw ProviderError.modelUnavailable("\(model.availability)")
            }
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: "<DICTATION>\n\(transcript)\n</DICTATION>")
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ProviderError.emptyOutput }
            return text
        }
        #endif
        throw ProviderError.unsupportedOS
    }
}
