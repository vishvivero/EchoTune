//
//  ModelManager+ModelCatalog.swift
//  EchoTune
//
//  Model catalog — curated for Apple Silicon (M1-M5).
//  Only models that make sense: multilingual, fast, accurate.
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
                language: "Multilingual",
                url: URL(string: "https://developer.apple.com/documentation/speech")!,
                type: .fast,
                category: .local,
                speedRating: 4,
                accuracyRating: 3,
                isBuiltIn: true
            ),

            // MARK: - Local Models (WhisperKit / CoreML)

            // Recommended default — best speed/accuracy balance
            AIModel(
                id: "distil-whisper_distil-large-v3_turbo_600MB",
                name: "Distil Large v3 Turbo",
                size: 600 * 1024 * 1024,
                description: "Recommended. Fastest large model — distilled + turbo optimized. Great on all Apple Silicon.",
                language: "Multilingual (19 languages)",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 4
            ),

            // Premium accuracy — for users who want the best
            AIModel(
                id: "openai_whisper-large-v3-turbo",
                name: "Large v3 Turbo",
                size: 954 * 1024 * 1024,
                description: "Maximum accuracy with turbo speed. Best for M2+ with 16GB+ RAM.",
                language: "Multilingual (99 languages)",
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
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 3
            ),
            
            // MARK: - Neural Engine Models (Parakeet / FluidAudio)

            AIModel(
                id: "parakeet-tdt-0.6b-v3",
                name: "Parakeet TDT v3",
                size: 460 * 1024 * 1024,
                description: "Fastest local transcription. Runs on Apple Neural Engine — loads in seconds. 25 languages. ~120x realtime.",
                language: "Multilingual (25 European languages)",
                url: URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 4,
                isBuiltIn: false
            ),

            AIModel(
                id: "parakeet-tdt-0.6b-v2",
                name: "Parakeet TDT v2 (English)",
                size: 460 * 1024 * 1024,
                description: "English-optimised Parakeet. Same Neural Engine speed, tuned for maximum English accuracy.",
                language: "English",
                url: URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 4,
                isBuiltIn: false
            ),

            // MARK: - Cloud Models

            AIModel(
                id: "groq-whisper-large-v3-turbo",
                name: "Groq Whisper / Grok STT",
                size: 0,
                description: "Lightning-fast cloud transcription. Works with Groq gsk_ keys and xAI Grok xai- keys.",
                language: "Multilingual",
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
                language: "Multilingual",
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
