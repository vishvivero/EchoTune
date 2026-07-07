//
//  HistoryComponents.swift
//  EchoTune
//
//  Created by Vishnu Raj on 27/10/2025.
//

import SwiftUI
import AVFoundation

struct WaveformBar: View {
    let sample: Float
    let isPlayed: Bool
    
    var body: some View {
        Capsule()
            .fill(isPlayed ? Color.accentColor : Color.secondary.opacity(0.3))
            .frame(width: 2, height: max(CGFloat(sample) * 16, 2))
    }
}

struct WaveformView: View {
    let samples: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isLoading: Bool
    var onSeek: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 1.5) {
                        ForEach(0..<samples.count, id: \.self) { index in
                            WaveformBar(
                                sample: samples[index],
                                isPlayed: CGFloat(index) / CGFloat(samples.count) <= CGFloat(currentTime / max(0.01, duration))
                            )
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isLoading && duration > 0 {
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek(progress * duration)
                        }
                    }
            )
        }
        .frame(height: 24)
    }
}

struct TranscriptionHistoryRow: View {
    let item: TranscriptionHistoryItem
    let isRetranscribing: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onRetranscribe: () -> Void
    let onDeleteAudio: () -> Void
    let onUpdateText: (String) -> Void
    
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @State private var editedText: String = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let model = item.processingMetadata?.transcriptionModel {
                            Text(model)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !isExpanded {
                        Text(item.text)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Duration & Actions
                HStack(spacing: 12) {
                    Text(formatDuration(item.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.audioFilePath != nil {
                        Image(systemName: "waveform")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                    
                    Button(action: onToggleExpand) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }
            
            // Expanded content
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 14) {
                    // Editable transcription body
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Transcription")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if isEditing {
                                Button("Save") {
                                    onUpdateText(editedText)
                                    isEditing = false
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                                
                                Button("Cancel") {
                                    editedText = item.text
                                    isEditing = false
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            } else {
                                Button("Edit") {
                                    editedText = item.text
                                    isEditing = true
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if isEditing {
                            TextEditor(text: $editedText)
                                .frame(minHeight: 60, maxHeight: 150)
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                        } else {
                            Text(item.text)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Audio Player section if file is available
                    if let path = item.audioFilePath, FileManager.default.fileExists(atPath: path) {
                        let audioURL = URL(fileURLWithPath: path)
                        let isThisPlaying = audioPlayer.currentlyPlayingUrl == audioURL && audioPlayer.isPlaying
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Button(action: {
                                    if isThisPlaying {
                                        audioPlayer.pause()
                                    } else {
                                        audioPlayer.play(from: audioURL)
                                    }
                                }) {
                                    Image(systemName: isThisPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                
                                if audioPlayer.currentlyPlayingUrl == audioURL {
                                    WaveformView(
                                        samples: audioPlayer.waveformPeaks,
                                        currentTime: audioPlayer.currentTime,
                                        duration: audioPlayer.duration,
                                        isLoading: audioPlayer.isRenderingWaveform,
                                        onSeek: { audioPlayer.seek(to: $0) }
                                    )
                                } else {
                                    Button("Load waveform") {
                                        audioPlayer.loadAudio(from: audioURL)
                                    }
                                    .font(.caption)
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            HStack {
                                if audioPlayer.currentlyPlayingUrl == audioURL {
                                    Text(formatDuration(audioPlayer.currentTime))
                                        .font(.system(size: 9))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatDuration(audioPlayer.duration))
                                        .font(.system(size: 9))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("0:00")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatDuration(item.duration))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                    }
                    
                    // Additional Actions row
                    HStack(spacing: 14) {
                        if item.audioFilePath != nil {
                            Button(action: onDeleteAudio) {
                                Label("Delete Audio", systemImage: "waveform.slash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red.opacity(0.8))
                        }
                        
                        if item.audioFilePath != nil && !isRetranscribing {
                            Button(action: onRetranscribe) {
                                Label("Retranscribe", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        } else if isRetranscribing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        
                        Spacer()
                        
                        if let metadata = item.processingMetadata {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Provider: \(metadata.transcriptionProvider ?? "Local")")
                                if let latency = metadata.totalLatency {
                                    Text(String(format: "Latency: %.1fs", latency))
                                }
                            }
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color.primary.opacity(0.02))
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.textBackgroundColor).opacity(0.5)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            editedText = item.text
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
