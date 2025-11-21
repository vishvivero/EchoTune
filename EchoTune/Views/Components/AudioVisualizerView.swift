//
//  AudioVisualizerView.swift
//  EchoTune
//
//  Phase 2: Audio Level Visualization
//

import Combine
import SwiftUI

struct AudioVisualizerView: View {
    let audioLevel: Float
    let isRecording: Bool

    private let barCount = 20
    private let barSpacing: CGFloat = 2
    private let maxHeight: CGFloat = 40

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                BarView(
                    height: barHeight(for: index),
                    color: barColor(for: index),
                    isRecording: isRecording
                )
            }
        }
        .frame(height: maxHeight)
        .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isRecording else { return 2 }

        // Create a wave pattern based on audio level
        let normalizedLevel = CGFloat(min(max(audioLevel, 0), 1))

        // Apply a wave distribution across bars
        let centerIndex = Double(barCount) / 2
        let distance = abs(Double(index) - centerIndex)
        let waveEffect = 1.0 - (distance / centerIndex)

        let height = normalizedLevel * maxHeight * CGFloat(waveEffect)

        return max(height, 2) // Minimum height
    }

    private func barColor(for index: Int) -> Color {
        if !isRecording {
            return .gray.opacity(0.3)
        }

        let normalizedLevel = min(max(audioLevel, 0), 1)

        if normalizedLevel > 0.7 {
            return .green
        } else if normalizedLevel > 0.3 {
            return .blue
        } else {
            return .gray
        }
    }
}

// MARK: - Bar View

struct BarView: View {
    let height: CGFloat
    let color: Color
    let isRecording: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3, height: height)
            .shadow(color: isRecording ? color.opacity(0.5) : .clear, radius: 2)
    }
}

// MARK: - Preview

#Preview("Idle") {
    AudioVisualizerView(audioLevel: 0, isRecording: false)
        .padding()
        .frame(width: 300)
}

#Preview("Recording Low") {
    AudioVisualizerView(audioLevel: 0.3, isRecording: true)
        .padding()
        .frame(width: 300)
}

#Preview("Recording High") {
    AudioVisualizerView(audioLevel: 0.8, isRecording: true)
        .padding()
        .frame(width: 300)
}
