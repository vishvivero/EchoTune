//
//  AudioPlayerManager.swift
//  EchoTune
//
//  Extracted from HistoryView.swift
//

import Foundation
import AVFoundation
import Combine

// MARK: - Audio Player Manager

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()

    @Published var isPlaying = false
    @Published var currentlyPlayingId: UUID?
    @Published var playbackProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    private init() {}

    var currentTimeFormatted: String {
        return formatTime(currentTime)
    }

    var durationFormatted: String {
        return formatTime(duration)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func play(filePath: String, itemId: UUID) {
        // Stop any current playback
        stop()

        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            debugLog("❌ Audio file not found: \(filePath)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            currentlyPlayingId = itemId
            playbackProgress = 0.0
            duration = audioPlayer?.duration ?? 0.0
            currentTime = 0.0

            // Start progress timer
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                if player.isPlaying {
                    self.currentTime = player.currentTime
                    self.duration = player.duration
                    self.playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
                } else {
                    self.stop()
                }
            }

            debugLog("▶️ Playing audio: \(filePath)")
        } catch {
            debugLog("❌ Failed to play audio: \(error.localizedDescription)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentlyPlayingId = nil
        playbackProgress = 0.0
        currentTime = 0.0
        duration = 0.0
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func togglePlayback(filePath: String, itemId: UUID) {
        if currentlyPlayingId == itemId && isPlaying {
            stop()
        } else {
            play(filePath: filePath, itemId: itemId)
        }
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let clampedTime = max(0, min(time, player.duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
        playbackProgress = player.duration > 0 ? clampedTime / player.duration : 0
    }
}
