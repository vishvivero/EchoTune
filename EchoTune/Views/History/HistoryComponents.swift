//
//  HistoryComponents.swift
//  EchoTune
//
//  Extracted from HistoryView.swift
//  Contains WaveformView and TranscriptionHistoryRow
//

import SwiftUI
import AVFoundation
import AppKit

// MARK: - Waveform View

struct WaveformView: View {
    let audioFilePath: String
    let progress: Double
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var samples: [Float] = []
    private let barCount = 150

    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(1, (geometry.size.width - CGFloat(barCount - 1) * 1.5) / CGFloat(barCount))
            let totalBarSpace = barWidth + 1.5

            HStack(alignment: .center, spacing: 1.5) {
                ForEach(0..<samples.count, id: \.self) { index in
                    let normalizedHeight = CGFloat(samples[index]) * geometry.size.height
                    let barHeight = max(2, normalizedHeight)
                    let barProgress = Double(index) / Double(max(1, samples.count - 1))
                    let isPlayed = barProgress <= progress

                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPlayed ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0, min(1, value.location.x / geometry.size.width))
                        let seekTime = fraction * duration
                        onSeek(seekTime)
                    }
            )
        }
        .onAppear {
            loadWaveformSamples()
        }
    }

    private func loadWaveformSamples() {
        DispatchQueue.global(qos: .userInitiated).async {
            let generated = Self.generateSamples(from: audioFilePath, count: barCount)
            DispatchQueue.main.async {
                self.samples = generated
            }
        }
    }

    static func generateSamples(from filePath: String, count: Int) -> [Float] {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            return Array(repeating: 0.1, count: count)
        }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)

            guard frameCount > 0 else {
                return Array(repeating: 0.1, count: count)
            }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return Array(repeating: 0.1, count: count)
            }

            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData else {
                return Array(repeating: 0.1, count: count)
            }

            let data = channelData[0]
            let totalFrames = Int(buffer.frameLength)
            let samplesPerBar = max(1, totalFrames / count)

            var result: [Float] = []
            for i in 0..<count {
                let start = i * samplesPerBar
                let end = min(start + samplesPerBar, totalFrames)
                if start >= totalFrames { break }

                var sum: Float = 0
                for j in start..<end {
                    sum += abs(data[j])
                }
                let avg = sum / Float(end - start)
                result.append(avg)
            }

            // Normalize to 0...1
            let maxVal = result.max() ?? 1.0
            if maxVal > 0 {
                result = result.map { min(1.0, $0 / maxVal) }
            }

            // Ensure minimum bar height visibility
            result = result.map { max(0.05, $0) }

            return result

        } catch {
            debugLog("❌ Failed to generate waveform: \(error)")
            return Array(repeating: 0.1, count: count)
        }
    }
}

struct HistoryMetadataBadge: View {
    let title: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - History Row

struct TranscriptionHistoryRow: View {
    let item: TranscriptionHistoryItem
    let isRetranscribing: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onRetranscribe: () -> Void
    let onDeleteAudio: () -> Void
    let onUpdateText: (String) -> Void

    @ObservedObject private var audioPlayerManager = AudioPlayerManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var isHovering = false

    private var hasAudioFile: Bool {
        guard let path = item.audioFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private var audioFileSize: String? {
        guard let path = item.audioFilePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return AudioCleanupManager.shared.formatFileSize(size)
    }

    private var isCurrentlyPlaying: Bool {
        audioPlayerManager.currentlyPlayingId == item.id && audioPlayerManager.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary row
            HStack(spacing: 16) {
                // Icon / Play button
                ZStack {
                    Circle()
                        .fill(hasAudioFile ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)

                    if hasAudioFile {
                        Button(action: {
                            if let path = item.audioFilePath {
                                audioPlayerManager.togglePlayback(filePath: path, itemId: item.id)
                            }
                        }) {
                            Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help(isCurrentlyPlaying ? "Pause playback" : "Play recording")
                    } else {
                        Image(systemName: "text.quote")
                            .foregroundColor(.blue)
                    }
                }

                // Content (clickable to expand)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 2)

                    if item.transcriptionProviderLabel != nil || item.hasEnhancement || item.usedFallback {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                if let provider = item.transcriptionProviderLabel {
                                    HistoryMetadataBadge(title: provider, color: .blue, icon: "waveform.badge.mic")
                                }
                                if let model = item.transcriptionModelLabel {
                                    HistoryMetadataBadge(title: model, color: .secondary, icon: "cpu")
                                }
                                if let enhancementProvider = item.enhancementProviderLabel {
                                    HistoryMetadataBadge(title: "Enhanced • \(enhancementProvider)", color: .purple, icon: "sparkles")
                                }
                                if item.usedFallback {
                                    HistoryMetadataBadge(title: "Fallback", color: .orange, icon: "arrow.uturn.backward.circle")
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Label(item.formattedDate, systemImage: "calendar")
                        Label("\(item.wordCount) words", systemImage: "textformat")
                        Label(String(format: "%.1fs", item.duration), systemImage: "timer")

                        if let size = audioFileSize {
                            Label(size, systemImage: "waveform")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if settings.showTranscriptionDiagnostics, let diagnosticsLine = item.diagnosticsLine {
                        Text(diagnosticsLine)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggleExpand()
                }

                Spacer()

                // Expand indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggleExpand()
                    }

                // Hover actions (only when collapsed)
                if !isExpanded {
                    if isRetranscribing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 8)
                    } else if isHovering {
                        HStack(spacing: 8) {
                            if hasAudioFile {
                                Button(action: onRetranscribe) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                                .help("Re-transcribe with current model")

                                Button(action: onDeleteAudio) {
                                    Image(systemName: "waveform.badge.minus")
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                                .help("Delete audio file (keep transcript)")
                            }

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.text, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Copy to clipboard")

                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                    }
                }
            }
            .padding(16)

            // Playback progress bar (when collapsed and playing)
            if !isExpanded && isCurrentlyPlaying {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.1))
                            .frame(height: 3)

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * audioPlayerManager.playbackProgress, height: 3)
                    }
                }
                .frame(height: 3)
            }

            // Expanded detail view
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                TranscriptionDetailView(
                    item: item,
                    isRetranscribing: isRetranscribing,
                    onDelete: onDelete,
                    onRetranscribe: onRetranscribe,
                    onDeleteAudio: onDeleteAudio,
                    onUpdateText: onUpdateText
                )
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(isExpanded ? 0.08 : 0.04), radius: isExpanded ? 8 : 4, y: isExpanded ? 4 : 2)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
