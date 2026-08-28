//
//  ParakeetEngine.swift
//  EchoTune
//
//  Fast transcription engine using NVIDIA Parakeet TDT via FluidAudio CoreML.
//  Runs on Apple Neural Engine — ~120x realtime (1 min audio ≈ 0.5s on M4).
//  Loads in seconds (no CoreML compilation). 25 European languages.
//
//  FLUIDAUDIO INTEGRATION TODO:
//  The FluidAudio SPM package (v0.15.5) is already added to the project.
//  The real engine should use FluidAudio's ASR pipeline — see the
//  Getting Started doc at FluidInference/FluidAudio on GitHub.
//  Until integrated, transcription falls back to WhisperKit.
//

import Foundation
import AVFoundation
import Combine
import os.log

@available(macOS 14.0, *)
class ParakeetEngine: ObservableObject {

    static let shared = ParakeetEngine()

    // MARK: - Published State (mirrors WhisperEngine pattern)
    @Published var isAvailable: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStage: String = ""
    @Published var currentModelID: String?
    @Published var loadedModelName: String?

    private let wLog = OSLog(subsystem: "com.echotune", category: "Parakeet")

    private init() {
        os_log("🦜 ParakeetEngine initialized (stub — FluidAudio integration pending)", log: wLog, type: .info)
    }

    // MARK: - Model Loading (stub)

    func loadModel(_ model: AIModel, completion: @escaping (Result<Void, Error>) -> Void) {
        os_log("⚠️ Parakeet loadModel called but FluidAudio integration is pending", log: wLog, type: .info)
        isLoading = true
        loadingStage = "Parakeet requires FluidAudio integration"
        loadingProgress = 0.0

        // Not available until FluidAudio is wired up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoading = false
            self?.loadingProgress = 0
            self?.loadingStage = "Not available — using WhisperKit fallback"
            completion(.failure(ParakeetError.integrationPending))
        }
    }

    func unloadModel() {
        isAvailable = false
    }

    // MARK: - Transcription (stub)

    func transcribe(audioArray: [Float]) async throws -> WhisperTranscriptionResult {
        throw ParakeetError.integrationPending
    }

    func startStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        completion(.failure(ParakeetError.integrationPending))
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {}
    func stopStreamingTranscription(completion: @escaping (Result<WhisperTranscriptionResult, Error>) -> Void) {
        completion(.failure(ParakeetError.integrationPending))
    }
}

// MARK: - Errors

enum ParakeetError: LocalizedError {
    case modelNotLoaded
    case integrationPending

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Parakeet model is not loaded"
        case .integrationPending: return "FluidAudio integration is pending — using WhisperKit fallback"
        }
    }
}
