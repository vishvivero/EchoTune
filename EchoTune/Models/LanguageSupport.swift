//
//  LanguageSupport.swift
//  EchoTune
//
//  Multilingual transcription support

import Foundation

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
    let nativeName: String
    let code: String // ISO 639-1 code (e.g., "en", "es", "fr")
    
    var displayName: String {
        "\(name) (\(nativeName))"
    }
}

class LanguageManager {
    static let shared = LanguageManager()
    
    // Supported languages for transcription
    // Whisper API supports ~99 languages; Groq Whisper supports ~100
    let supportedLanguages: [Language] = [
        Language(id: "auto", name: "Auto-Detect", nativeName: "Auto", code: "auto"),
        Language(id: "en", name: "English", nativeName: "English", code: "en"),
        Language(id: "es", name: "Spanish", nativeName: "Español", code: "es"),
        Language(id: "fr", name: "French", nativeName: "Français", code: "fr"),
        Language(id: "de", name: "German", nativeName: "Deutsch", code: "de"),
        Language(id: "it", name: "Italian", nativeName: "Italiano", code: "it"),
        Language(id: "pt", name: "Portuguese", nativeName: "Português", code: "pt"),
        Language(id: "nl", name: "Dutch", nativeName: "Nederlands", code: "nl"),
        Language(id: "pl", name: "Polish", nativeName: "Polski", code: "pl"),
        Language(id: "ru", name: "Russian", nativeName: "Русский", code: "ru"),
        Language(id: "ja", name: "Japanese", nativeName: "日本語", code: "ja"),
        Language(id: "ko", name: "Korean", nativeName: "한국어", code: "ko"),
        Language(id: "zh", name: "Chinese (Mandarin)", nativeName: "中文", code: "zh"),
        Language(id: "ar", name: "Arabic", nativeName: "العربية", code: "ar"),
        Language(id: "hi", name: "Hindi", nativeName: "हिन्दी", code: "hi"),
        Language(id: "th", name: "Thai", nativeName: "ไทย", code: "th"),
        Language(id: "tr", name: "Turkish", nativeName: "Türkçe", code: "tr"),
        Language(id: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", code: "id"),
        Language(id: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", code: "vi"),
    ]
    
    func language(for code: String) -> Language? {
        supportedLanguages.first { $0.code == code }
    }
    
    func languageByID(_ id: String) -> Language? {
        supportedLanguages.first { $0.id == id }
    }
}

// MARK: - Transcription Language Options

enum TranscriptionLanguageMode: String, Codable {
    case auto = "auto"          // Auto-detect language
    case fixed = "fixed"        // Use fixed language
    case detectAndTranslate = "detectAndTranslate"  // Detect + translate to English
}

// MARK: - Translation Support

struct TranslationRequest {
    let text: String
    let sourceLanguage: String  // ISO 639-1 code
    let targetLanguage: String  // ISO 639-1 code (default: "en")
}

// Note: Translation is typically handled by:
// 1. Groq's translation models (e.g., via model: "mixtral-8x7b-32768")
// 2. OpenAI's GPT models
// 3. Dedicated translation APIs (Google Translate, DeepL, etc.)
// This will be integrated into AIEnhancementEngine.swift
