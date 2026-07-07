//
//  SpeakerDiarizer.swift
//  EchoTune
//
//  Simple speaker diarization using silence detection + voice fingerprinting.
//  Identifies speaker changes based on gaps in speech and audio characteristics.
//

import Foundation
import AVFoundation
import Accelerate

class SpeakerDiarizer {
    static let shared = SpeakerDiarizer()

    // MARK: - Speaker Profile

    struct SpeakerProfile {
        var label: String           // "Speaker 1", "Speaker 2", etc.
        var avgEnergy: Float        // Average RMS energy
        var avgPitch: Float         // Estimated fundamental frequency
        var segmentCount: Int       // How many segments attributed
    }

    struct SpeakerSegment {
        let speakerLabel: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
    }

    // MARK: - State

    private var speakers: [SpeakerProfile] = []
    private var currentSpeakerIndex: Int = -1
    private var lastSpeechEndTime: Date?
    private var currentSegmentStartTime: Date?
    private let silenceGapThreshold: TimeInterval = 1.0  // 1s silence = potential speaker change
    private let energyMatchThreshold: Float = 0.4        // How close energy must be to match speaker
    private let pitchMatchThreshold: Float = 40.0        // Hz tolerance for pitch matching
    private var segmentBuffers: [AVAudioPCMBuffer] = []

    init() {}

    // MARK: - Reset

    func reset() {
        speakers.removeAll()
        currentSpeakerIndex = -1
        lastSpeechEndTime = nil
        currentSegmentStartTime = nil
        segmentBuffers.removeAll()
    }

    // MARK: - Process Audio Buffer

    /// Call this with each audio buffer during recording.
    /// Returns the current speaker label if speech is detected, nil if silence.
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> String? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return nil }

        // Calculate RMS energy
        let energy = calculateRMS(channelData, count: frameCount)

        // Is this speech or silence?
        let isSpeech = energy > 0.005

        let now = Date()

        if isSpeech {
            // Check if this is a new speech segment after a gap
            if let lastEnd = lastSpeechEndTime {
                let gap = now.timeIntervalSince(lastEnd)
                if gap > silenceGapThreshold {
                    // Silence gap detected — potential speaker change
                    let pitch = estimatePitch(channelData, count: frameCount, sampleRate: Float(buffer.format.sampleRate))
                    let matchedIndex = findMatchingSpeaker(energy: energy, pitch: pitch)

                    if matchedIndex >= 0 {
                        currentSpeakerIndex = matchedIndex
                        speakers[matchedIndex].segmentCount += 1
                        // Update running average
                        let n = Float(speakers[matchedIndex].segmentCount)
                        speakers[matchedIndex].avgEnergy = (speakers[matchedIndex].avgEnergy * (n - 1) + energy) / n
                        if pitch > 0 {
                            speakers[matchedIndex].avgPitch = (speakers[matchedIndex].avgPitch * (n - 1) + pitch) / n
                        }
                    } else {
                        // New speaker
                        let newSpeaker = SpeakerProfile(
                            label: "Speaker \(speakers.count + 1)",
                            avgEnergy: energy,
                            avgPitch: pitch,
                            segmentCount: 1
                        )
                        speakers.append(newSpeaker)
                        currentSpeakerIndex = speakers.count - 1
                    }
                    currentSegmentStartTime = now
                }
            } else {
                // First speech ever — create first speaker
                if speakers.isEmpty {
                    let pitch = estimatePitch(channelData, count: frameCount, sampleRate: Float(buffer.format.sampleRate))
                    let newSpeaker = SpeakerProfile(
                        label: "Speaker 1",
                        avgEnergy: energy,
                        avgPitch: pitch,
                        segmentCount: 1
                    )
                    speakers.append(newSpeaker)
                    currentSpeakerIndex = 0
                    currentSegmentStartTime = now
                }
            }

            lastSpeechEndTime = now
            return currentSpeakerLabel
        } else {
            // Silence — just update last speech time tracking
            return nil
        }
    }

    var currentSpeakerLabel: String? {
        guard currentSpeakerIndex >= 0 && currentSpeakerIndex < speakers.count else { return nil }
        return speakers[currentSpeakerIndex].label
    }

    var speakerCount: Int { speakers.count }

    // MARK: - Speaker Matching

    private func findMatchingSpeaker(energy: Float, pitch: Float) -> Int {
        guard !speakers.isEmpty else { return -1 }

        var bestMatch = -1
        var bestScore: Float = .infinity

        for (index, speaker) in speakers.enumerated() {
            // Combined distance metric: energy difference + pitch difference
            let energyDiff = abs(energy - speaker.avgEnergy) / max(speaker.avgEnergy, 0.001)
            let pitchDiff: Float
            if pitch > 0 && speaker.avgPitch > 0 {
                pitchDiff = abs(pitch - speaker.avgPitch)
            } else {
                pitchDiff = 0  // Can't compare pitch, rely on energy only
            }

            let score = energyDiff + (pitchDiff / 100.0)

            if score < bestScore {
                bestScore = score
                bestMatch = index
            }
        }

        // Only match if score is good enough
        if bestScore < energyMatchThreshold + (pitchMatchThreshold / 100.0) {
            return bestMatch
        }

        return -1  // No good match — likely a new speaker
    }

    // MARK: - Audio Analysis

    private func calculateRMS(_ data: UnsafePointer<Float>, count: Int) -> Float {
        var sum: Float = 0
        for i in 0..<count {
            sum += data[i] * data[i]
        }
        return sqrt(sum / Float(max(count, 1)))
    }

    /// Simple pitch estimation using autocorrelation
    private func estimatePitch(_ data: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        guard count > 256 else { return 0 }

        let analysisSize = min(count, 2048)

        // Autocorrelation-based pitch detection
        // Look for periodicity in the 80-400 Hz range (human voice)
        let minLag = Int(sampleRate / 400)  // 400 Hz upper bound
        let maxLag = Int(sampleRate / 80)   // 80 Hz lower bound

        guard maxLag < analysisSize else { return 0 }

        var bestCorrelation: Float = 0
        var bestLag = 0

        for lag in minLag..<min(maxLag, analysisSize / 2) {
            var correlation: Float = 0
            var energy: Float = 0

            for i in 0..<(analysisSize - lag) {
                correlation += data[i] * data[i + lag]
                energy += data[i] * data[i]
            }

            if energy > 0 {
                let normalized = correlation / energy
                if normalized > bestCorrelation {
                    bestCorrelation = normalized
                    bestLag = lag
                }
            }
        }

        // Only return pitch if we have strong periodicity
        guard bestCorrelation > 0.3 && bestLag > 0 else { return 0 }

        return sampleRate / Float(bestLag)
    }

    // MARK: - Post-process transcript with speaker labels

    /// Takes a full transcript and splits it by speaker based on accumulated diarization data.
    /// This is a simplified version — it labels based on the current speaker tracking.
    func labelTranscript(_ text: String) -> String {
        guard speakerCount > 1 else { return text }  // Don't label if only 1 speaker detected
        guard let label = currentSpeakerLabel else { return text }
        return "[\(label)] \(text)"
    }
}
