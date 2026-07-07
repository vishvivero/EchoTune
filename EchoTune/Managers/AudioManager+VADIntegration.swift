//
//  AudioManager+VADIntegration.swift
//  EchoTune
//
//  Voice Activity Detection integration — speech analysis helpers
//  Split from AudioManager.swift
//

import Foundation
import AVFoundation

// MARK: - VAD Integration

extension AudioManager {

    /// Get VAD analysis of recorded audio
    func getVADAnalysis() -> VADManager.AnalysisResult? {
        guard !recordedVADHistory.isEmpty else {
            debugLog("⚠️ No recorded VAD history available for analysis")
            return nil
        }

        guard let format = recordingFormat else {
            debugLog("⚠️ No recording format available")
            return nil
        }

        return VADManager.shared.analyzeSpeechSegments(
            from: recordedVADHistory,
            sampleRate: format.sampleRate
        )
    }

    /// Check if recording has significant speech
    func hasSignificantSpeech() -> Bool {
        guard !recordedVADHistory.isEmpty else {
            return false
        }

        return VADManager.shared.hasSignificantSpeech(in: recordedVADHistory)
    }
}
