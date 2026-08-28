//
//  ModelManager+ModelCatalog.swift
//  EchoTune
//
//  Model catalog — curated for Apple Silicon (M1-M5).
//  Only models that make sense: fast, accurate (English-optimised for this release).
//

import Foundation

// MARK: - Model Catalog

extension ModelManager {

    func loadAvailableModels() {
        availableModels = [

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
                isBuiltIn: true
            ),

            // MARK: - Local Models (WhisperKit / CoreML)

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

            // Recommended balance — best speed/accuracy for most Macs
            AIModel(
                id: "distil-whisper_distil-large-v3",
                name: "Distil Large v3",
                size: 594 * 1024 * 1024,
                description: "Nearly large-v3 accuracy at a fraction of the load. The best free speed + accuracy pick.",
                language: "English",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 4,
                isBuiltIn: false
            ),

            // Fastest distilled default — compatible with all Apple Silicon
            AIModel(
                id: "distil-whisper_distil-large-v3_turbo_600MB",
                name: "Distil Large v3 Turbo",
                size: 600 * 1024 * 1024,
                description: "Recommended. Fastest large model — distilled + turbo optimized. Great on all Apple Silicon.",
                language: "English",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 4
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

            // Premium accuracy — for users who want the best
            AIModel(
                id: "openai_whisper-large-v3-turbo",
                name: "Large v3 Turbo",
                size: 954 * 1024 * 1024,
                description: "Maximum accuracy with turbo speed. Best for M2+ with 16GB+ RAM.",
                language: "English",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 3,
                accuracyRating: 5
            ),

            // M1-compatible base model (turbo not supported on M1)
            AIModel(
                id: "openai_whisper-base",
                name: "Base",
                size: 143 * 1024 * 1024,
                description: "Lightweight model compatible with all Apple Silicon (including M1) and Intel Macs.",
                language: "English",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 3
            ),

            // MARK: - Cloud Models

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
                isBuiltIn: false
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
                isBuiltIn: false
            ),
        ]
    }
}
