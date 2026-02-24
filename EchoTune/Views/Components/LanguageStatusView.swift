//
//  LanguageStatusView.swift
//  EchoTune
//
//  Displays current transcription language and translation status

import SwiftUI

struct LanguageStatusView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    var detectedLanguage: String?
    var isTranslating: Bool = false
    
    private var languageLabel: String {
        if let detected = detectedLanguage, settings.autoDetectLanguage {
            if let lang = LanguageManager.shared.language(for: detected) {
                return "Detected: \(lang.name)"
            }
            return "Detected: \(detected)"
        } else if !settings.autoDetectLanguage {
            if let lang = LanguageManager.shared.language(for: settings.preferredLanguage) {
                return "Language: \(lang.name)"
            }
            return "Language: \(settings.preferredLanguage)"
        }
        return "Auto-Detect"
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Language badge
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text(languageLabel)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(4)
            
            // Translation indicator
            if settings.translateToEnglish {
                HStack(spacing: 4) {
                    if isTranslating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "translate")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    Text(isTranslating ? "Translating..." : "Translation On")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
            }
            
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Auto-Detect Example")
            .font(.caption).fontWeight(.bold)
        LanguageStatusView(detectedLanguage: "es", isTranslating: false)
        
        Text("Translation Active Example")
            .font(.caption).fontWeight(.bold)
        LanguageStatusView(detectedLanguage: "fr", isTranslating: true)
        
        Text("Fixed Language Example")
            .font(.caption).fontWeight(.bold)
        LanguageStatusView(detectedLanguage: nil, isTranslating: false)
    }
    .padding()
}
