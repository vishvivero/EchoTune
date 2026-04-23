//
//  AppCoordinator+Retranscription.swift
//  EchoTune
//
//  Re-transcription of saved audio files with a different model.
//

import Foundation

struct RetranscriptionResult {
    let text: String
    let rawTranscriptionText: String
    let processingMetadata: TranscriptionProcessingMetadata
}

// MARK: - Re-Transcription

extension AppCoordinator {

    /// Re-transcribe a saved audio file with the currently selected model
    func retranscribe(historyItem: TranscriptionHistoryItem, completion: @escaping (RetranscriptionResult?) -> Void) {
        guard let audioPath = historyItem.audioFilePath,
              FileManager.default.fileExists(atPath: audioPath) else {
            debugLog("❌ Audio file not found for re-transcription")
            completion(nil)
            return
        }

        guard let currentModel = modelManager.currentModel else {
            debugLog("❌ No model selected for re-transcription")
            notificationManager.showNotification(
                title: "Re-Transcription Failed",
                body: "Please select a transcription model first.",
                sound: false
            )
            completion(nil)
            return
        }

        debugLog("🔄 Re-transcribing with model: \(currentModel.name)")

        // Read audio data from file
        guard let audioData = try? Data(contentsOf: URL(fileURLWithPath: audioPath)) else {
            debugLog("❌ Failed to read audio file")
            completion(nil)
            return
        }

        let startTime = Date()

        func buildMetadata(provider: String, model: String) -> TranscriptionProcessingMetadata {
            var metadata = TranscriptionProcessingMetadata()
            metadata.transcriptionProvider = provider
            metadata.transcriptionModel = model
            metadata.audioByteCount = audioData.count
            metadata.recordingDuration = historyItem.duration
            let latency = Date().timeIntervalSince(startTime)
            metadata.transcriptionLatency = latency
            metadata.totalLatency = latency
            metadata.qualityFeedback = historyItem.processingMetadata?.qualityFeedback
            return metadata
        }

        // Route to appropriate transcription service
        if currentModel.category == .cloud {
            Task {
                do {
                    let transcribedText: String
                    let metadata: TranscriptionProcessingMetadata

                    if currentModel.id.contains("groq") || currentModel.name.lowercased().contains("groq") {
                        let apiKey = settings.groqAPIKey
                        guard !apiKey.isEmpty else {
                            await MainActor.run { completion(nil) }
                            return
                        }
                        transcribedText = try await GroqTranscriptionService.shared.transcribe(
                            audioData: audioData,
                            language: AppSettings.shared.autoDetectLanguage ? nil : settings.preferredLanguage.components(separatedBy: "-").first,
                            apiKey: apiKey
                        )
                        metadata = buildMetadata(provider: "Groq", model: "whisper-large-v3-turbo")
                    } else if currentModel.id.contains("deepgram") || currentModel.name.lowercased().contains("deepgram") {
                        let apiKey = settings.deepgramAPIKey
                        guard !apiKey.isEmpty else {
                            await MainActor.run { completion(nil) }
                            return
                        }
                        transcribedText = try await DeepgramTranscriptionService.shared.transcribeToText(
                            audioData: audioData,
                            model: .nova,
                            language: AppSettings.shared.autoDetectLanguage ? nil : settings.preferredLanguage.components(separatedBy: "-").first,
                            apiKey: apiKey
                        )
                        metadata = buildMetadata(provider: "Deepgram", model: "nova-2")
                    } else {
                        await MainActor.run { completion(nil) }
                        return
                    }

                    await MainActor.run {
                        debugLog("✅ Re-transcription successful: \(transcribedText.prefix(50))...")
                        notificationManager.showNotification(
                            title: "Re-Transcription Complete",
                            body: "Transcription updated with \(currentModel.name).",
                            sound: false
                        )
                        completion(
                            RetranscriptionResult(
                                text: transcribedText,
                                rawTranscriptionText: transcribedText,
                                processingMetadata: metadata
                            )
                        )
                    }
                } catch {
                    await MainActor.run {
                        debugLog("❌ Re-transcription failed: \(error)")
                        notificationManager.showNotification(
                            title: "Re-Transcription Failed",
                            body: error.localizedDescription,
                            sound: false
                        )
                        completion(nil)
                    }
                }
            }
        } else {
            // For local Whisper models, load and transcribe
            if currentModel.category == .local && !currentModel.isBuiltIn {
                let finishLocal: (WhisperTranscriptionResult) -> Void = { payload in
                    let metadata = buildMetadata(provider: "Local Whisper", model: currentModel.name)
                    debugLog("✅ Re-transcription (Whisper) successful")
                    self.notificationManager.showNotification(
                        title: "Re-Transcription Complete",
                        body: "Transcription updated with \(currentModel.name).",
                        sound: false
                    )
                    completion(
                        RetranscriptionResult(
                            text: payload.outputText,
                            rawTranscriptionText: payload.outputText,
                            processingMetadata: metadata
                        )
                    )
                }

                let failLocal: (Error) -> Void = { error in
                    debugLog("❌ Re-transcription failed: \(error)")
                    self.notificationManager.showNotification(
                        title: "Re-Transcription Failed",
                        body: error.localizedDescription,
                        sound: false
                    )
                    completion(nil)
                }

                // Load model if needed
                if !whisperEngine.isAvailable || whisperEngine.loadedModelName != currentModel.name {
                    whisperEngine.loadModel(currentModel) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success:
                            self.whisperEngine.transcribeAudio(audioData) { result in
                                switch result {
                                case .success(let payload):
                                    finishLocal(payload)
                                case .failure(let error):
                                    failLocal(error)
                                }
                            }
                        case .failure(let error):
                            debugLog("❌ Failed to load model for re-transcription: \(error)")
                            self.notificationManager.showNotification(
                                title: "Re-Transcription Failed",
                                body: "Failed to load model: \(error.localizedDescription)",
                                sound: false
                            )
                            completion(nil)
                        }
                    }
                } else {
                    whisperEngine.transcribeAudio(audioData) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success(let payload):
                            finishLocal(payload)
                        case .failure(let error):
                            failLocal(error)
                        }
                    }
                }
            } else {
                // Built-in Apple Speech — use audio data transcription
                transcriptionEngine.transcribeAudio(audioData) { [weak self] result in
                    switch result {
                    case .success(let text):
                        let metadata = buildMetadata(provider: "Apple Speech", model: "Built-in")
                        debugLog("✅ Re-transcription (Apple Speech) successful")
                        self?.notificationManager.showNotification(
                            title: "Re-Transcription Complete",
                            body: "Transcription updated with Apple Speech.",
                            sound: false
                        )
                        completion(
                            RetranscriptionResult(
                                text: text,
                                rawTranscriptionText: text,
                                processingMetadata: metadata
                            )
                        )
                    case .failure(let error):
                        debugLog("❌ Re-transcription failed: \(error)")
                        self?.notificationManager.showNotification(
                            title: "Re-Transcription Failed",
                            body: error.localizedDescription,
                            sound: false
                        )
                        completion(nil)
                    }
                }
            }
        }
    }
}
