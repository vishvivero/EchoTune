//
//  TranscriptionEngine+Routing.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import Foundation
import Speech
import AVFoundation

// MARK: - Model Routing Helpers

extension TranscriptionEngine {

    func routeToGroq(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        let apiKey = AppSettings.shared.groqAPIKey
        guard !apiKey.isEmpty else {
            debugLog("❌ Groq API key not configured")
            completion(.failure(.unavailable))
            return
        }

        debugLog("📡 Routing to Groq transcription service")
        Task {
            do {
                let language = AppSettings.shared.autoDetectLanguage ? nil : AppSettings.shared.preferredLanguage.components(separatedBy: "-").first
                let text = try await GroqTranscriptionService.shared.transcribe(
                    audioData: audioData,
                    language: language,
                    apiKey: apiKey
                )
                await MainActor.run {
                    let processed = self.processText(text)
                    completion(.success(processed))
                }
            } catch {
                await MainActor.run {
                    debugLog("❌ Groq transcription failed: \(error)")
                    completion(.failure(.recognitionError(error)))
                }
            }
        }
    }

    func routeToDeepgram(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        let apiKey = AppSettings.shared.deepgramAPIKey
        guard !apiKey.isEmpty else {
            debugLog("❌ Deepgram API key not configured")
            completion(.failure(.unavailable))
            return
        }

        debugLog("📡 Routing to Deepgram transcription service")
        Task {
            do {
                let language = AppSettings.shared.autoDetectLanguage ? nil : AppSettings.shared.preferredLanguage.components(separatedBy: "-").first
                let text = try await DeepgramTranscriptionService.shared.transcribeToText(
                    audioData: audioData,
                    model: .nova,
                    language: language,
                    apiKey: apiKey
                )
                await MainActor.run {
                    let processed = self.processText(text)
                    completion(.success(processed))
                }
            } catch {
                await MainActor.run {
                    debugLog("❌ Deepgram transcription failed: \(error)")
                    completion(.failure(.recognitionError(error)))
                }
            }
        }
    }

    func routeToWhisper(_ audioData: Data, selectedModel: String, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        debugLog("🎙️ Routing to local Whisper engine: \(selectedModel)")

        let whisperEngine = WhisperEngine.shared
        let modelManager = ModelManager.shared

        // Find the AIModel for the selected model ID
        guard let aiModel = modelManager.availableModels.first(where: { $0.id == selectedModel }) else {
            debugLog("❌ Model not found in available models: \(selectedModel)")
            completion(.failure(.processingError))
            return
        }

        // Check if the correct model is already loaded
        if whisperEngine.isAvailable && whisperEngine.loadedModelName == aiModel.name {
            // Model is loaded, transcribe directly
            whisperEngine.transcribeAudio(audioData) { result in
                switch result {
                case .success(let transcription):
                    completion(.success(transcription.outputText))
                case .failure(let error):
                    debugLog("❌ Whisper transcription failed: \(error)")
                    completion(.failure(.processingError))
                }
            }
        } else {
            // Need to load the model first
            debugLog("📦 Loading Whisper model before transcription: \(aiModel.name)")
            whisperEngine.loadModel(aiModel) { [weak self] loadResult in
                switch loadResult {
                case .success:
                    whisperEngine.transcribeAudio(audioData) { result in
                        switch result {
                        case .success(let transcription):
                            completion(.success(transcription.outputText))
                        case .failure(let error):
                            debugLog("❌ Whisper transcription failed after model load: \(error)")
                            completion(.failure(.processingError))
                        }
                    }
                case .failure(let error):
                    debugLog("❌ Failed to load Whisper model: \(error)")
                    completion(.failure(.processingError))
                }
            }
        }
    }

    // NOTE: This method duplicates the Apple Speech path in transcribeAudio. Consider removing.
    func transcribeWithAppleSpeech(_ audioData: Data, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        guard isAvailable else {
            completion(.failure(.unavailable))
            return
        }

        guard isPermissionGranted else {
            completion(.failure(.permissionDenied))
            return
        }

        isProcessing = true
        currentText = ""

        // Create temporary file for audio data (using CAF format for better Float32 support)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("transcription.caf")

        do {
            try audioData.write(to: tempURL)

            debugLog("📄 Wrote audio data to temp file: \(tempURL.path)")
            debugLog("   File size: \(audioData.count) bytes")

            // Use URL-based recognition instead of buffer-based
            let urlRequest = SFSpeechURLRecognitionRequest(url: tempURL)
            urlRequest.shouldReportPartialResults = false

            debugLog("🎯 Starting URL-based speech recognition...")

            guard let speechRecognizer = self.speechRecognizer else {
                debugLog("❌ Speech recognizer not available")
                self.isProcessing = false
                completion(.failure(.unavailable))
                return
            }

            recognitionTask = speechRecognizer.recognitionTask(with: urlRequest) { [weak self] result, error in
                guard let self = self else { return }

                if let error = error {
                    debugLog("❌ Recognition error: \(error)")
                    self.isProcessing = false
                    completion(.failure(.recognitionError(error)))
                    return
                }

                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    self.currentText = transcription

                    if result.isFinal {
                        debugLog("✅ Final transcription: \(transcription)")
                        self.isProcessing = false
                        let processedText = self.processText(transcription)
                        completion(.success(processedText))
                    }
                }
            }

            if recognitionTask == nil {
                debugLog("❌ Failed to create recognition task")
                self.isProcessing = false
                completion(.failure(.unavailable))
            }
        } catch {
            debugLog("❌ Error: \(error)")
            isProcessing = false
            completion(.failure(.audioFormatError))
        }
    }
}
