//
//  MenuBarIconRenderer.swift
//  EchoTune
//
//  Renders a crisp monochrome template (`isTemplate = true`) 20x20pt (@2x 40x40px)
//  plain transparent rounded-square outline with the EchoTune waveform logo inside.
//  macOS automatically renders template black pixels as pure white in the menu bar
//  with zero color fill and a completely transparent interior.
//

import AppKit
import CoreGraphics

enum MenuBarIconRenderer {
    static let canvasSize = NSSize(width: 20, height: 20)

    enum VisualState: Equatable {
        case idle
        case recording(level: Float)
        case processing(phase: Double)
        case loading(progress: Double)
        case error
    }

    static func render(state: VisualState) -> NSImage {
        let scale: CGFloat = 2.0
        let pixelWidth = Int(canvasSize.width * scale)
        let pixelHeight = Int(canvasSize.height * scale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: canvasSize)
        }
        rep.size = canvasSize

        NSGraphicsContext.saveGraphicsState()
        if let gfx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = gfx
            let ctx = gfx.cgContext
            ctx.setShouldAntialias(true)
            drawTransparentRoundedSquareWithWaveform(
                in: CGRect(origin: .zero, size: canvasSize),
                state: state,
                ctx: ctx
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        image.isTemplate = true
        image.accessibilityDescription = "EchoTune"
        return image
    }

    private static func drawTransparentRoundedSquareWithWaveform(
        in rect: CGRect,
        state: VisualState,
        ctx: CGContext
    ) {
        // Plain transparent rounded-square border (18x18pt inside 20x20pt canvas)
        let strokeRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let radius: CGFloat = 4.4
        let borderPath = CGPath(
            roundedRect: strokeRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.92).cgColor)
        ctx.setLineWidth(1.35)
        ctx.addPath(borderPath)
        ctx.strokePath()

        // EchoTune 5-bar waveform logo centered inside the transparent square
        let heights = barHeights(for: state)
        let hasBottomBar: Bool
        let bottomProgress: CGFloat
        if case .loading(let p) = state {
            hasBottomBar = true
            bottomProgress = CGFloat(min(1.0, max(0.12, p)))
        } else {
            hasBottomBar = false
            bottomProgress = 0
        }

        let barWidth: CGFloat = 1.65
        let gap: CGFloat = 1.15
        let count = heights.count
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        let startX = strokeRect.midX - totalWidth / 2.0
        let centerY = hasBottomBar ? strokeRect.midY + 0.9 : strokeRect.midY

        ctx.setFillColor(NSColor.black.cgColor)
        for (idx, rawH) in heights.enumerated() {
            let maxH: CGFloat = hasBottomBar ? 8.2 : 10.2
            let h = max(2.4, min(maxH, rawH))
            let x = startX + CGFloat(idx) * (barWidth + gap)
            let y = centerY - h / 2.0
            let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
            let barPath = CGPath(
                roundedRect: barRect,
                cornerWidth: barWidth / 2.0,
                cornerHeight: barWidth / 2.0,
                transform: nil
            )
            ctx.addPath(barPath)
            ctx.fillPath()
        }

        if hasBottomBar {
            let trackRect = CGRect(
                x: strokeRect.minX + 2.6,
                y: strokeRect.minY + 1.9,
                width: strokeRect.width - 5.2,
                height: 1.4
            )
            let trackPath = CGPath(roundedRect: trackRect, cornerWidth: 0.7, cornerHeight: 0.7, transform: nil)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.28).cgColor)
            ctx.addPath(trackPath)
            ctx.fillPath()

            let fillRect = CGRect(
                x: trackRect.minX,
                y: trackRect.minY,
                width: max(1.8, trackRect.width * bottomProgress),
                height: trackRect.height
            )
            let fillPath = CGPath(roundedRect: fillRect, cornerWidth: 0.7, cornerHeight: 0.7, transform: nil)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(fillPath)
            ctx.fillPath()
        }
    }

    private static func barHeights(for state: VisualState) -> [CGFloat] {
        switch state {
        case .idle:
            return [3.6, 6.6, 9.8, 6.6, 3.6]
        case .loading:
            return [3.2, 5.6, 7.8, 5.6, 3.2]
        case .error:
            return [3.8, 5.8, 8.8, 5.8, 3.8]
        case .recording(let level):
            let clamped = CGFloat(min(1.0, max(0.08, level * 2.4)))
            return [
                3.2 + clamped * 4.2,
                4.4 + clamped * 5.6,
                5.4 + clamped * 4.8,
                4.4 + clamped * 5.8,
                3.2 + clamped * 4.4
            ]
        case .processing(let phase):
            return (0..<5).map { idx in
                let wave = (sin(phase + Double(idx) * 0.85) + 1.0) * 0.5
                return 3.2 + CGFloat(wave) * 6.6
            }
        }
    }
}
