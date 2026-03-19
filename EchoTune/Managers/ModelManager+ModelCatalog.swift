//
//  ModelManager+ModelCatalog.swift
//  EchoTune
//
//  Extracted from ModelManager.swift — model catalog definitions.
//

import Foundation

// MARK: - Model Catalog

extension ModelManager {

    func loadAvailableModels() {
        // Define available Whisper models (will use WhisperKit for loading)
        availableModels = [
            // Built-in Apple Speech
            AIModel(
                id: "apple-speech",
                name: "Apple Speech",
                size: 0,
                description: "Uses native Apple Speech framework for transcription",
                language: "Multilingual",
                url: URL(string: "builtin://apple-speech")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 3,
                isBuiltIn: true
            ),
            // Supported Whisper local models (downloadable via WhisperKit)

            // Tiny models
            AIModel(
                id: "tiny.en",
                name: "Tiny (English)",
                size: 75 * 1024 * 1024, // 75MB
                description: "Tiny model, fastest, less accurate",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 2
            ),
            AIModel(
                id: "tiny",
                name: "Tiny",
                size: 75 * 1024 * 1024,
                description: "Tiny model, fastest, less accurate, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 5,
                accuracyRating: 2
            ),

            // Base models
            AIModel(
                id: "base.en",
                name: "Base (English)",
                size: 143 * 1024 * 1024, // 143MB
                description: "Base model, good balance between speed and accuracy",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 4,
                accuracyRating: 3
            ),
            AIModel(
                id: "base",
                name: "Base",
                size: 143 * 1024 * 1024,
                description: "Base model, good balance between speed and accuracy, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 4,
                accuracyRating: 3
            ),

            // Small models
            AIModel(
                id: "small.en",
                name: "Small (English)",
                size: 488 * 1024 * 1024, // 488MB
                description: "Small model, better accuracy, slower",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 3,
                accuracyRating: 4
            ),
            AIModel(
                id: "small",
                name: "Small",
                size: 488 * 1024 * 1024,
                description: "Small model, better accuracy, slower, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 3,
                accuracyRating: 4
            ),

            // Medium models
            AIModel(
                id: "medium.en",
                name: "Medium (English)",
                size: 1500 * 1024 * 1024, // 1.5GB
                description: "Medium model, high accuracy, requires more resources",
                language: "English only",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 2,
                accuracyRating: 4
            ),
            AIModel(
                id: "medium",
                name: "Medium",
                size: 1500 * 1024 * 1024,
                description: "Medium model, high accuracy, requires more resources, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 2,
                accuracyRating: 4
            ),

            // Large v3
            AIModel(
                id: "large-v3",
                name: "Large v3",
                size: 2900 * 1024 * 1024, // 2.9GB
                description: "Largest model, best accuracy, slowest, supports multiple languages",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .accurate,
                category: .local,
                speedRating: 1,
                accuracyRating: 5
            ),

            // Large v3 Turbo (Optimized/Quantized)
            AIModel(
                id: "openai_whisper-large-v3_turbo",
                name: "Large v3 Turbo",
                size: 954 * 1024 * 1024, // 954MB (3x smaller!)
                description: "Optimized Large v3: 2-3x faster, same accuracy, uses quantization",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .balanced,
                category: .local,
                speedRating: 3,
                accuracyRating: 5
            ),

            // Distilled Large v3 Turbo (Fastest large model)
            AIModel(
                id: "distil-whisper_distil-large-v3_turbo",
                name: "Distil Large v3 Turbo",
                size: 600 * 1024 * 1024, // 600MB (5x smaller!)
                description: "Distilled + Turbo: Fastest large model, 3-4x faster than base large-v3",
                language: "Multilingual",
                url: URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml")!,
                type: .fast,
                category: .local,
                speedRating: 4,
                accuracyRating: 4
            ),
            // Cloud models (require API key)
            AIModel(
                id: "groq-whisper-large-v3-turbo",
                name: "Groq Whisper",
                size: 0,
                description: "Lightning-fast cloud transcription via Groq (requires API key)",
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
                name: "Deepgram Nova 2",
                size: 0,
                description: "High-accuracy cloud transcription via Deepgram (requires API key)",
                language: "Multilingual",
                url: URL(string: "https://console.deepgram.com")!,
                type: .accurate,
                category: .cloud,
                speedRating: 4,
                accuracyRating: 5,
                isBuiltIn: false
            ),

            // Coming soon list (not selectable, no download)
            AIModel(
                id: "parakeet-v3",
                name: "Parakeet V3",
                size: 2200 * 1024 * 1024,
                description: "High-quality local ASR (coming soon)",
                language: "Multilingual",
                url: URL(string: "comingsoon://parakeet-v3")!,
                type: .accurate,
                category: .comingSoon,
                speedRating: 2,
                accuracyRating: 5
            ),
        ]
    }
}
