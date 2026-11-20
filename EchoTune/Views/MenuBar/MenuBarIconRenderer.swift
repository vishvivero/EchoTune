//
//  MenuBarIconRenderer.swift
//  EchoTune
//
//  Crisp 1:1 Retina CoreGraphics status-bar icon renderer inspired by CodexBar.
//  Renders pixel-aligned waveform bars with state tints and a 2pt bottom
//  progress bar when loading or downloading models.
//

import AppKit
import CoreGraphics

enum MenuBarIconRenderer {
    static let canvasSize = NSSize(width: 18, height: 18)

    enum VisualState: Equatable {
        case idle
        case recording(level: Float)
        case processing(phase: Double)
        case loading(progress: Double)
        case error
    }

    static func render(state: VisualState) -> NSImage {
        let isTemplate: Bool
        switch state {
        case .idle, .loading:
            isTemplate = true
        case .recording, .processing, .error:
            isTemplate = false
        }

        let image = NSImage(size: canvasSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setShouldAntialias(true)

            let barColor = resolvedBarColor(for: state)
            let heights = barHeights(for: state)
            let hasBottomBar: Bool
            let bottomProgress: CGFloat

            switch state {
            case .loading(let progress):
                hasBottomBar = true
                bottomProgress = CGFloat(min(1.0, max(0.08, progress)))
            default:
                hasBottomBar = false
                bottomProgress = 0
            }

            // 5 crisp vertical rounded bars centered in 18x18pt
            let barWidth: CGFloat = 2.0
            let gap: CGFloat = 1.5
            let count = heights.count
            let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
            let startX = round((rect.width - totalWidth) / 2.0 * 2.0) / 2.0
            let centerY: CGFloat = hasBottomBar ? 10.2 : 9.0

            ctx.setFillColor(barColor.cgColor)
            for (index, rawHeight) in heights.enumerated() {
                let h = max(3.0, min(hasBottomBar ? 11.5 : 14.0, rawHeight))
                let x = startX + CGFloat(index) * (barWidth + gap)
                let y = centerY - h / 2.0
                let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
                let path = CGPath(
                    roundedRect: barRect,
                    cornerWidth: barWidth / 2.0,
                    cornerHeight: barWidth / 2.0,
                    transform: nil
                )
                ctx.addPath(path)
                ctx.fillPath()
            }

            // Recording live micro-dot in top-right corner
            if case .recording = state {
                let dotRect = CGRect(x: rect.width - 4.2, y: rect.height - 4.5, width: 3.2, height: 3.2)
                ctx.setFillColor(NSColor.systemRed.cgColor)
                ctx.fillEllipse(in: dotRect)
            }

            // CodexBar-style 2pt bottom progress track when downloading/compiling a model
            if hasBottomBar {
                let trackRect = CGRect(x: 2.0, y: 1.5, width: rect.width - 4.0, height: 2.0)
                let trackPath = CGPath(roundedRect: trackRect, cornerWidth: 1.0, cornerHeight: 1.0, transform: nil)
                ctx.setFillColor(barColor.withAlphaComponent(0.26).cgColor)
                ctx.addPath(trackPath)
                ctx.fillPath()

                let fillWidth = max(2.0, trackRect.width * bottomProgress)
                let fillRect = CGRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
                let fillPath = CGPath(roundedRect: fillRect, cornerWidth: 1.0, cornerHeight: 1.0, transform: nil)
                ctx.setFillColor(barColor.cgColor)
                ctx.addPath(fillPath)
                ctx.fillPath()
            }

            return true
        }

        image.isTemplate = isTemplate
        image.accessibilityDescription = "EchoTune"
        return image
    }

    private static func resolvedBarColor(for state: VisualState) -> NSColor {
        switch state {
        case .idle, .loading:
            return .labelColor
        case .recording:
            return .systemRed
        case .processing:
            return .controlAccentColor
        case .error:
            return .systemOrange
        }
    }

    private static func barHeights(for state: VisualState) -> [CGFloat] {
        switch state {
        case .idle:
            return [4.5, 8.5, 12.5, 8.5, 4.5]
        case .loading:
            return [4.0, 7.5, 10.5, 7.5, 4.0]
        case .error:
            return [5.0, 7.0, 11.0, 7.0, 5.0]
        case .recording(let level):
            let clamped = CGFloat(min(1.0, max(0.05, level * 2.4)))
            return [
                4.0 + clamped * 5.0,
                5.5 + clamped * 7.5,
                7.0 + clamped * 7.0,
                5.5 + clamped * 8.0,
                4.0 + clamped * 5.5
            ]
        case .processing(let phase):
            return (0..<5).map { idx in
                let wave = (sin(phase + Double(idx) * 0.85) + 1.0) * 0.5
                return 4.0 + CGFloat(wave) * 9.0
            }
        }
    }
}
