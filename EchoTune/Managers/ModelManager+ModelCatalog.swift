//
//  ModelManager+ModelCatalog.swift
//  EchoTune
//
//  Model catalog — curated roster for Apple Silicon (M1-M5) and Intel Macs.
//  Kept deliberately short: one recommended default, one lighter Whisper, one
//  slim Whisper flagship, and the two verified FluidAudio language models.
//  The built-in Apple Speech entry stays as the zero-download fallback, and the
//  cloud providers stay behind the API-key gate in Settings.
//

import Foundation

// MARK: - Model Catalog

extension ModelManager {

    func loadAvailableModels() {
        availableModels = [

            // MARK: - Recommended default

            // Recommended on every Mac: fastest verified local model, runs on
            // the Neural Engine through FluidAudio. This is the model onboarding
            // and Settings surface first, and the one new installs select.
            AIModel(
                id: AIModel.recommendedModelID,
                name: "Parakeet TDT v3",
                size: 600 * 1024 * 1024,
                description: "Latest fast on-device English transcription using FluidAudio and the Neural Engine.",
                language: "English",
                url: URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 4,
                backend: .parakeet
            ),

            // MARK: - WhisperKit / CoreML

            // Budget tier — light English dictation on 8GB Macs
            AIModel(
                id: "openai_whisper-small.en",
                name: "Small (English)",
                size: 244 * 1024 * 1024,
                description: "Noticeably more accurate than Base for English, still light enough for 8GB Macs.",
                language: "English",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 3,
                isBuiltIn: false
            ),

            // Slim flagship — v3 turbo accuracy, ~34% smaller download
            AIModel(
                id: "openai_whisper-large-v3-v20240930_turbo",
                name: "Large v3 Turbo (slim)",
                size: 632 * 1024 * 1024,
                description: "Max accuracy with turbo speed — and 34% smaller than the classic turbo. Best on M2+.",
                language: "English",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 4,
                accuracyRating: 5,
                isBuiltIn: false
            ),

            // MARK: - Multilingual FluidAudio Models

            AIModel(
                id: "paraformer-large-zh",
                name: "Paraformer Large (中文)",
                size: 435_730_164,
                description: "Experimental Mandarin on-device ASR using FluidAudio's Paraformer pipeline.",
                language: "Mandarin (zh)",
                fixedLanguage: "zh-CN",
                url: URL(string: "https://huggingface.co/FluidInference/paraformer-large-zh-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 3,
                accuracyRating: 3,
                backend: .paraformer
            ),

            AIModel(
                id: "parakeet-ja-0.6b",
                name: "Parakeet 0.6B (日本語)",
                size: 619_049_694,
                description: "Experimental Japanese TDT model using FluidAudio's verified hybrid adapter.",
                language: "Japanese (ja)",
                fixedLanguage: "ja-JP",
                url: URL(string: "https://huggingface.co/FluidInference/parakeet-0.6b-ja-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 3,
                accuracyRating: 3,
                backend: .parakeet
            ),

            // MARK: - Built-in fallback (no download)

            AIModel(
                id: "apple-speech",
                name: "Apple Speech",
                size: 0,
                description: "Built-in macOS transcription. No download required.",
                language: "English",
                url: URL(string: "https://developer.apple.com/documentation/speech")!,
                type: .fast,
                category: .local,
                speedRating: 4,
                accuracyRating: 3,
                isBuiltIn: true,
                backend: .appleSpeech
            ),

            // MARK: - Cloud Models (shown once a key is stored)

            AIModel(
                id: "groq-whisper-large-v3-turbo",
                name: "Groq Whisper / Grok STT",
                size: 0,
                description: "Lightning-fast cloud transcription. Works with Groq gsk_ keys and xAI Grok xai- keys.",
                language: "English",
                url: URL(string: "https://console.groq.com")!,
                type: .fast,
                category: .cloud,
                speedRating: 5,
                accuracyRating: 5,
                isBuiltIn: false,
                backend: .groq
            ),

            AIModel(
                id: "deepgram-nova",
                name: "Deepgram Nova",
                size: 0,
                description: "Cloud transcription via Deepgram's Nova model. Requires a Deepgram API key.",
                language: "English",
                url: URL(string: "https://deepgram.com")!,
                type: .fast,
                category: .cloud,
                speedRating: 5,
                accuracyRating: 4,
                isBuiltIn: false,
                backend: .deepgram
            ),
        ]
    }
}
