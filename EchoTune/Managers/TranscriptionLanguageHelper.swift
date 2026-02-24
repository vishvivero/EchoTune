//
//  TranscriptionLanguageHelper.swift
//  EchoTune
//
//  Helper to manage language parameters for transcription services

import Foundation

class TranscriptionLanguageHelper {
    static let shared = TranscriptionLanguageHelper()
    
    // MARK: - Language Code Mapping
    
    /// Convert EchoTune language code to Whisper/Groq language code
    func whisperLanguageCode(for ecoLanguageCode: String) -> String? {
        // Whisper uses ISO 639-1 codes
        // Map any custom codes to standard ISO codes if needed
        
        switch ecoLanguageCode.lowercased() {
        case "auto": return nil  // Let Whisper auto-detect
        case "zh": return "zh"   // Mandarin Chinese
        case "pt": return "pt"   // Portuguese (both BR and PT)
        case "en": return "en"
        case "es": return "es"
        case "fr": return "fr"
        case "de": return "de"
        case "it": return "it"
        case "nl": return "nl"
        case "pl": return "pl"
        case "ru": return "ru"
        case "ja": return "ja"
        case "ko": return "ko"
        case "ar": return "ar"
        case "hi": return "hi"
        case "th": return "th"
        case "tr": return "tr"
        case "id": return "id"
        case "vi": return "vi"
        default: return ecoLanguageCode
        }
    }
    
    // MARK: - Transcription Request Building
    
    /// Build language parameters for Groq Whisper API
    func groqLanguageParams() -> [String: Any] {
        let settings = AppSettings.shared
        var params: [String: Any] = [:]
        
        if !settings.autoDetectLanguage {
            if let langCode = whisperLanguageCode(for: settings.preferredLanguage) {
                params["language"] = langCode
            }
        }
        
        // Note: Groq's language detection is high-quality
        // If auto-detect is enabled, omit the language parameter
        
        return params
    }
    
    /// Build language parameters for Whisper (OpenAI or similar)
    func whisperLanguageParams() -> [String: Any] {
        let settings = AppSettings.shared
        var params: [String: Any] = [:]
        
        if !settings.autoDetectLanguage {
            if let langCode = whisperLanguageCode(for: settings.preferredLanguage) {
                params["language"] = langCode
            }
        }
        
        return params
    }
    
    // MARK: - Language Detection & Metadata
    
    /// Extract detected language from transcription response
    /// Groq returns: { "language": "es", ... }
    /// Whisper returns: { "language": "spanish", ... }
    func extractDetectedLanguage(from response: [String: Any]) -> String? {
        if let language = response["language"] as? String {
            return language
        }
        return nil
    }
    
    /// Get language name from detected code
    func languageName(for code: String) -> String {
        return LanguageManager.shared.language(for: code)?.name ?? code
    }
    
    // MARK: - Translation
    
    /// Check if translation is enabled and should be performed
    func shouldTranslate() -> Bool {
        let settings = AppSettings.shared
        return settings.translateToEnglish
    }
    
    /// Build translation prompt for AI models
    func translationPrompt(for text: String, sourceLanguage: String) -> String {
        let langName = languageName(for: sourceLanguage)
        return """
        Translate the following \(langName) text to English. Preserve formatting, technical terms, and context. Return ONLY the translated text, nothing else:
        
        \(text)
        """
    }
    
    /// Build translation system message for AI models
    var translationSystemMessage: String {
        """
        You are a professional translator. Your role is to accurately translate text while preserving:
        - Original meaning and tone
        - Technical and proper nouns
        - Formatting and structure
        - Context and idioms
        
        Respond with ONLY the translation, no explanations or metadata.
        """
    }
    
    // MARK: - Performance Optimization
    
    /// Check if language is known to have high quality with Whisper
    func isHighQualityLanguage(_ code: String) -> Bool {
        // Whisper has highest quality for these languages
        let highQualityLanguages = ["en", "es", "fr", "de", "it", "pt", "nl", "pl", "ru", "ja", "ko", "zh"]
        return highQualityLanguages.contains(code.lowercased())
    }
    
    /// Estimate processing time impact of translation
    func estimatedTranslationLatency() -> TimeInterval {
        // Typical latency: 2-5 seconds for translation via AI
        // Varies by model and text length
        return 3.0  // Default estimate
    }
}

// MARK: - Transcription Result Extension

struct TranscriptionResult {
    let text: String
    let detectedLanguage: String?
    let translatedText: String?
    let confidence: Float?
    let duration: TimeInterval
}
