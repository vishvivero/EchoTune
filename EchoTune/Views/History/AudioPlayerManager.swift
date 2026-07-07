//
//  AudioPlayerManager.swift
//  EchoTune
//
//  Playback controller for archived dictation audio in the History tab,
//  plus peak rendering for the seek-bar waveform. One clip plays at a time;
//  loading a new clip replaces the previous one.
//

import Foundation
import AVFoundation
import Combine

final class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()

    // MARK: - Published State

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var waveformPeaks: [Float] = []
    @Published var isRenderingWaveform = false
    @Published var currentlyPlayingUrl: URL? = nil

    // MARK: - Internals

    private var player: AVAudioPlayer?
    private var progressTicker: AnyCancellable?
    private var waveformTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    // MARK: - Loading

    /// Prepares a clip for playback and kicks off waveform rendering.
    func loadAudio(from url: URL) {
        // Reset any prior clip first.
        stop()

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            currentlyPlayingUrl = url
        } catch {
            debugLog("🔇 Could not open audio clip: \(error.localizedDescription)")
            currentlyPlayingUrl = nil
            return
        }

        renderWaveform(for: url)
    }

    // MARK: - Transport

    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        startProgressTicker()
    }

    func play(from url: URL) {
        if currentlyPlayingUrl != url {
            loadAudio(from: url)
        }
        play()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTicker()
    }

    func stop() {
        player?.stop()
        player = nil
        stopProgressTicker()
        waveformTask?.cancel()
        isPlaying = false
        currentTime = 0
        duration = 0
        waveformPeaks = []
        currentlyPlayingUrl = nil
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(time, 0), player.duration)
        currentTime = player.currentTime
    }

    func cleanup() {
        stop()
    }

    // MARK: - Progress

    private func startProgressTicker() {
        progressTicker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
    }

    private func stopProgressTicker() {
        progressTicker?.cancel()
        progressTicker = nil
    }

    // MARK: - Waveform Rendering

    /// Downmixes the clip to per-bucket peak amplitudes for the seek bar.
    private func renderWaveform(for url: URL, buckets: Int = 100) {
        waveformTask?.cancel()
        isRenderingWaveform = true
        waveformPeaks = []

        waveformTask = Task.detached(priority: .userInitiated) { [weak self] in
            let peaks = Self.renderPeaks(for: url, bucketCount: buckets)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.currentlyPlayingUrl == url else { return }
                self.waveformPeaks = peaks
                self.isRenderingWaveform = false
            }
        }
    }

    /// Reads the whole clip once and reduces it to `bucketCount` normalized
    /// peak values in 0...1. Returns an empty array when the file is unreadable.
    private static func renderPeaks(for url: URL, bucketCount: Int) -> [Float] {
        guard bucketCount > 0,
              let file = try? AVAudioFile(forReading: url) else {
            return []
        }

        let frameTotal = AVAudioFrameCount(file.length)
        guard frameTotal > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameTotal),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData?[0] else {
            return []
        }

        let frames = Int(buffer.frameLength)
        let framesPerBucket = max(frames / bucketCount, 1)

        var peaks = [Float](repeating: 0, count: bucketCount)
        for bucket in 0..<bucketCount {
            let start = bucket * framesPerBucket
            guard start < frames else { break }
            let end = min(start + framesPerBucket, frames)

            var peak: Float = 0
            for frame in start..<end {
                peak = max(peak, abs(channel[frame]))
            }
            // Perceptual curve: quiet speech still shows visible bars.
            peaks[bucket] = pow(peak, 0.6)
        }

        let ceiling = peaks.max() ?? 0
        guard ceiling > 0 else { return peaks }
        return peaks.map { $0 / ceiling }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.currentTime = 0
            self.stopProgressTicker()
        }
    }
}
