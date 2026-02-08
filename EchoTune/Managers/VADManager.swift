//
//  VADManager.swift
//  EchoTune
//
//  Phase 2: Voice Activity Detection
//  Detects speech vs silence to optimize transcription
//

import Foundation
import AVFoundation
import Accelerate

class VADManager {
    static let shared = VADManager()

    // MARK: - Configuration

    enum DetectionMethod {
        case energyBased    // Fast, no ML model needed
        case sileroVAD      // ML-based (Phase 6C - Silero VAD v5)
    }

    enum Sensitivity {
        case low
        case medium
        case high

        var threshold: Float {
            switch self {
            case .low: return 0.002     // More permissive (detects faint speech)
            case .medium: return 0.005  // Balanced
            case .high: return 0.010    // Strict (only loud/clear speech)
            }
        }
    }

    struct VADConfig {
        var method: DetectionMethod = .energyBased
        var sensitivity: Sensitivity = .medium
        var minimumSpeechDuration: TimeInterval = 0.3
        var minimumSilenceDuration: TimeInterval = 1.5
        var speechConfidenceThreshold: Float = 0.5
        var enabled: Bool = true
    }

    var config: VADConfig {
        didSet {
            debugLog("🎙️ VAD Config updated: \(config)")
        }
    }

    // MARK: - State

    private var speechHistory: [SpeechProbability] = []
    private var lastSpeechTimestamp: Date?
    private var silenceStartTimestamp: Date?

    // MARK: - Results

    struct SpeechProbability {
        let probability: Float       // 0.0 - 1.0
        let timestamp: Date
        let rmsLevel: Float         // Raw audio level
        let isSpeech: Bool

        var confidence: Float {
            // Convert probability to confidence (0-100%)
            return probability * 100.0
        }
    }

    struct AnalysisResult {
        let speechPercentage: Float           // 0.0 - 100.0
        let speechSegments: [SpeechSegment]
        let totalDuration: TimeInterval
        let speechDuration: TimeInterval
        let silenceDuration: TimeInterval
        let averageSpeechProbability: Float
        let hasSignificantSpeech: Bool

        var summary: String {
            """
            VAD Analysis:
              Speech: \(String(format: "%.1f", speechPercentage))% (\(String(format: "%.2f", speechDuration))s)
              Silence: \(String(format: "%.1f", 100.0 - speechPercentage))% (\(String(format: "%.2f", silenceDuration))s)
              Segments: \(speechSegments.count)
              Avg Confidence: \(String(format: "%.1f", averageSpeechProbability * 100))%
              Has Speech: \(hasSignificantSpeech ? "✅ Yes" : "❌ No")
            """
        }
    }

    struct SpeechSegment {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let averageProbability: Float
        let peakProbability: Float
        let rmsLevel: Float

        var duration: TimeInterval {
            return endTime - startTime
        }
    }

    // MARK: - Initialization

    init() {
        // Load configuration from UserDefaults
        self.config = VADConfig(
            method: .energyBased,
            sensitivity: Sensitivity(rawValue: UserDefaults.standard.integer(forKey: "vadSensitivity")) ?? .medium,
            minimumSpeechDuration: UserDefaults.standard.double(forKey: "vadMinimumSpeechDuration") != 0 ?
                UserDefaults.standard.double(forKey: "vadMinimumSpeechDuration") : 0.3,
            minimumSilenceDuration: UserDefaults.standard.double(forKey: "vadAutoStopDelay") != 0 ?
                UserDefaults.standard.double(forKey: "vadAutoStopDelay") : 1.5,
            enabled: UserDefaults.standard.bool(forKey: "vadEnabled")
        )

        debugLog("🎙️ VAD Manager initialized")
        debugLog("   Method: \(config.method)")
        debugLog("   Sensitivity: \(config.sensitivity)")
        debugLog("   Enabled: \(config.enabled)")
    }

    // MARK: - Real-Time Speech Detection

    /// Detect speech in a single audio buffer (for real-time monitoring during recording)
    func detectSpeech(in buffer: AVAudioPCMBuffer) -> SpeechProbability {
        guard config.enabled else {
            return SpeechProbability(probability: 1.0, timestamp: Date(), rmsLevel: 0, isSpeech: true)
        }

        switch config.method {
        case .energyBased:
            return detectSpeechEnergyBased(in: buffer)
        case .sileroVAD:
            return detectSpeechSileroVAD(in: buffer)
        }
    }

    /// Energy-based speech detection (fast, no ML model needed)
    private func detectSpeechEnergyBased(in buffer: AVAudioPCMBuffer) -> SpeechProbability {
        guard let channelData = buffer.floatChannelData else {
            return SpeechProbability(probability: 0.0, timestamp: Date(), rmsLevel: 0, isSpeech: false)
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            return SpeechProbability(probability: 0.0, timestamp: Date(), rmsLevel: 0, isSpeech: false)
        }

        // Calculate RMS (Root Mean Square) energy
        let rms = calculateRMS(channelData: channelData[0], frameCount: frameCount)

        // Convert RMS to speech probability (0.0-1.0)
        let threshold = config.sensitivity.threshold
        let probability = min(1.0, rms / (threshold * 3.0)) // Normalize to 0-1

        // Determine if this is speech
        let isSpeech = rms > threshold

        let result = SpeechProbability(
            probability: probability,
            timestamp: Date(),
            rmsLevel: rms,
            isSpeech: isSpeech
        )

        // Track speech history for silence detection
        speechHistory.append(result)
        if speechHistory.count > 100 {
            speechHistory.removeFirst()
        }

        // Update timestamps
        if isSpeech {
            lastSpeechTimestamp = Date()
            silenceStartTimestamp = nil
        } else if lastSpeechTimestamp != nil && silenceStartTimestamp == nil {
            silenceStartTimestamp = Date()
        }

        return result
    }

    /// Calculate RMS energy of audio samples using Accelerate framework
    private func calculateRMS(channelData: UnsafePointer<Float>, frameCount: Int) -> Float {
        var rms: Float = 0.0

        // Use vDSP for fast RMS calculation
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))

        return rms
    }

    /// Silero VAD-based speech detection (ML-based, more accurate)
    private func detectSpeechSileroVAD(in buffer: AVAudioPCMBuffer) -> SpeechProbability {
        // Check if Silero VAD is ready
        guard SileroVADEngine.shared.isReady() else {
            debugLog("⚠️ Silero VAD not ready, falling back to energy-based")
            return detectSpeechEnergyBased(in: buffer)
        }

        // Get speech probability from Silero VAD
        let probability = SileroVADEngine.shared.detectSpeech(in: buffer)

        // Calculate RMS for consistency with energy-based method
        var rms: Float = 0.0
        if let channelData = buffer.floatChannelData {
            rms = calculateRMS(channelData: channelData[0], frameCount: Int(buffer.frameLength))
        }

        // Determine if this is speech based on configured threshold
        let isSpeech = probability > config.speechConfidenceThreshold

        let result = SpeechProbability(
            probability: probability,
            timestamp: Date(),
            rmsLevel: rms,
            isSpeech: isSpeech
        )

        // Track speech history for silence detection
        speechHistory.append(result)
        if speechHistory.count > 100 {
            speechHistory.removeFirst()
        }

        // Update timestamps
        if isSpeech {
            lastSpeechTimestamp = Date()
            silenceStartTimestamp = nil
        } else if lastSpeechTimestamp != nil && silenceStartTimestamp == nil {
            silenceStartTimestamp = Date()
        }

        return result
    }

    // MARK: - Batch Analysis (After Recording)

    /// Analyze entire audio recording to determine speech vs silence
    func analyzeSpeechSegments(from buffers: [AVAudioPCMBuffer], sampleRate: Double = 48000.0) -> AnalysisResult {
        guard config.enabled else {
            // If VAD disabled, assume all speech
            let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
            let duration = Double(totalFrames) / sampleRate

            return AnalysisResult(
                speechPercentage: 100.0,
                speechSegments: [SpeechSegment(startTime: 0, endTime: duration, averageProbability: 1.0, peakProbability: 1.0, rmsLevel: 0)],
                totalDuration: duration,
                speechDuration: duration,
                silenceDuration: 0,
                averageSpeechProbability: 1.0,
                hasSignificantSpeech: true
            )
        }

        debugLog("🎙️ Analyzing \(buffers.count) audio buffers for speech...")

        var segments: [SpeechSegment] = []
        var currentSegmentStart: TimeInterval?
        var currentSegmentProbabilities: [Float] = []
        var currentSegmentRMS: [Float] = []

        var totalSpeechFrames = 0
        var totalFrames = 0
        var allProbabilities: [Float] = []

        var currentTime: TimeInterval = 0.0
        let frameTime = 1.0 / sampleRate

        for buffer in buffers {
            let frameCount = Int(buffer.frameLength)
            totalFrames += frameCount

            // Detect speech in this buffer
            let detection = detectSpeech(in: buffer)
            allProbabilities.append(detection.probability)

            if detection.isSpeech {
                totalSpeechFrames += frameCount

                // Start or continue speech segment
                if currentSegmentStart == nil {
                    currentSegmentStart = currentTime
                }
                currentSegmentProbabilities.append(detection.probability)
                currentSegmentRMS.append(detection.rmsLevel)

            } else {
                // End speech segment if one was active
                if let startTime = currentSegmentStart {
                    let endTime = currentTime
                    let avgProb = currentSegmentProbabilities.reduce(0, +) / Float(currentSegmentProbabilities.count)
                    let peakProb = currentSegmentProbabilities.max() ?? 0
                    let avgRMS = currentSegmentRMS.reduce(0, +) / Float(currentSegmentRMS.count)

                    segments.append(SpeechSegment(
                        startTime: startTime,
                        endTime: endTime,
                        averageProbability: avgProb,
                        peakProbability: peakProb,
                        rmsLevel: avgRMS
                    ))

                    currentSegmentStart = nil
                    currentSegmentProbabilities.removeAll()
                    currentSegmentRMS.removeAll()
                }
            }

            currentTime += Double(frameCount) * frameTime
        }

        // Close any remaining segment
        if let startTime = currentSegmentStart {
            let avgProb = currentSegmentProbabilities.reduce(0, +) / Float(currentSegmentProbabilities.count)
            let peakProb = currentSegmentProbabilities.max() ?? 0
            let avgRMS = currentSegmentRMS.reduce(0, +) / Float(currentSegmentRMS.count)

            segments.append(SpeechSegment(
                startTime: startTime,
                endTime: currentTime,
                averageProbability: avgProb,
                peakProbability: peakProb,
                rmsLevel: avgRMS
            ))
        }

        // Calculate statistics
        let totalDuration = Double(totalFrames) / sampleRate
        let speechDuration = Double(totalSpeechFrames) / sampleRate
        let silenceDuration = totalDuration - speechDuration
        let speechPercentage = (Float(totalSpeechFrames) / Float(totalFrames)) * 100.0
        let avgProbability = allProbabilities.isEmpty ? 0 : allProbabilities.reduce(0, +) / Float(allProbabilities.count)

        // Determine if there's significant speech (>10% of audio is speech)
        let hasSignificantSpeech = speechPercentage > 10.0

        let result = AnalysisResult(
            speechPercentage: speechPercentage,
            speechSegments: segments,
            totalDuration: totalDuration,
            speechDuration: speechDuration,
            silenceDuration: silenceDuration,
            averageSpeechProbability: avgProbability,
            hasSignificantSpeech: hasSignificantSpeech
        )

        debugLog("📊 VAD Analysis complete:")
        debugLog(result.summary)

        return result
    }

    /// Check if there's significant speech in the recording
    func hasSignificantSpeech(in buffers: [AVAudioPCMBuffer]) -> Bool {
        let analysis = analyzeSpeechSegments(from: buffers)
        return analysis.hasSignificantSpeech
    }

    // MARK: - Silence Detection (for Auto-Stop)

    /// Check if we should auto-stop due to sustained silence
    func shouldAutoStop() -> Bool {
        guard config.enabled else { return false }

        guard let silenceStart = silenceStartTimestamp else {
            return false
        }

        let silenceDuration = Date().timeIntervalSince(silenceStart)
        return silenceDuration >= config.minimumSilenceDuration
    }

    /// Get current silence duration
    func getCurrentSilenceDuration() -> TimeInterval? {
        guard let silenceStart = silenceStartTimestamp else {
            return nil
        }
        return Date().timeIntervalSince(silenceStart)
    }

    // MARK: - State Management

    /// Reset VAD state (call when starting new recording)
    func resetState() {
        speechHistory.removeAll()
        lastSpeechTimestamp = nil
        silenceStartTimestamp = nil

        // Reset Silero VAD state if using ML-based detection
        if config.method == .sileroVAD {
            SileroVADEngine.shared.resetState()
        }

        debugLog("🎙️ VAD state reset")
    }

    /// Get recent speech activity summary
    func getRecentActivity(seconds: TimeInterval = 5.0) -> (speechCount: Int, silenceCount: Int, avgProbability: Float) {
        let cutoffTime = Date().addingTimeInterval(-seconds)
        let recentHistory = speechHistory.filter { $0.timestamp >= cutoffTime }

        let speechCount = recentHistory.filter { $0.isSpeech }.count
        let silenceCount = recentHistory.count - speechCount
        let avgProb = recentHistory.isEmpty ? 0 : recentHistory.map { $0.probability }.reduce(0, +) / Float(recentHistory.count)

        return (speechCount, silenceCount, avgProb)
    }

    // MARK: - Configuration

    func updateSensitivity(_ sensitivity: Sensitivity) {
        config.sensitivity = sensitivity
        UserDefaults.standard.set(sensitivity.rawValue, forKey: "vadSensitivity")
        debugLog("🎙️ VAD sensitivity updated: \(sensitivity)")
    }

    func setEnabled(_ enabled: Bool) {
        config.enabled = enabled
        UserDefaults.standard.set(enabled, forKey: "vadEnabled")
        debugLog("🎙️ VAD \(enabled ? "enabled" : "disabled")")
    }
}

// MARK: - Sensitivity RawRepresentable

extension VADManager.Sensitivity: RawRepresentable {
    typealias RawValue = Int

    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .low
        case 1: self = .medium
        case 2: self = .high
        default: return nil
        }
    }

    var rawValue: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}
