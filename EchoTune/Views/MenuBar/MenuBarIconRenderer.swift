//
//  MenuBarIconRenderer.swift
//  EchoTune
//
//  Renders a monochrome template (`isTemplate = true`) 22x22pt (@2x 44x44px
//  concrete NSBitmapImageRep) rounded-square outline badge with a nearly
//  transparent interior fill (`alpha = 0.06` so macOS 26 ControlCenter still
//  hit-tests every pixel inside the square!) and the crisp EchoTune waveform
//  logo centered inside. Renders pure white in dark/vibrant menu bars with
//  zero color fill.
//

import AppKit
import CoreGraphics

enum MenuBarIconRenderer {
    static let canvasSize = NSSize(width: 22, height: 22)

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
            drawMonochromeBadge(in: CGRect(origin: .zero, size: canvasSize), state: state, ctx: ctx)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        // Template mode: macOS renders black RGB pixels as pure white in the
        // menu bar (and adapts automatically on light menu bars) — zero color!
        image.isTemplate = true
        image.accessibilityDescription = "EchoTune"
        return image
    }

    private static func drawMonochromeBadge(in rect: CGRect, state: VisualState, ctx: CGContext) {
        let badgeRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let radius: CGFloat = 4.8

        // 1. Nearly invisible interior hit-test fill (alpha = 0.05): visually transparent,
        //    yet non-zero alpha guarantees 100% click hit-testing across the whole square.
        let fillPath = CGPath(
            roundedRect: badgeRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.05).cgColor)
        ctx.addPath(fillPath)
        ctx.fillPath()

        // 2. Crisp plain white rounded-square border
        let strokeRect = badgeRect.insetBy(dx: 0.65, dy: 0.65)
        let strokePath = CGPath(
            roundedRect: strokeRect,
            cornerWidth: radius - 0.4,
            cornerHeight: radius - 0.4,
            transform: nil
        )
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.92).cgColor)
        ctx.setLineWidth(1.35)
        ctx.addPath(strokePath)
        ctx.strokePath()

        // 3. EchoTune waveform logo bars inside the rounded square
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

        let barWidth: CGFloat = 1.75
        let gap: CGFloat = 1.25
        let count = heights.count
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        let startX = badgeRect.midX - totalWidth / 2.0
        let centerY = hasBottomBar ? badgeRect.midY + 1.0 : badgeRect.midY

        ctx.setFillColor(NSColor.black.cgColor)
        for (idx, rawH) in heights.enumerated() {
            let maxH: CGFloat = hasBottomBar ? 8.8 : 11.0
            let h = max(2.6, min(maxH, rawH))
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

        // 4. Subtle monochrome progress line inside bottom of square when loading
        if hasBottomBar {
            let trackRect = CGRect(
                x: badgeRect.minX + 3.0,
                y: badgeRect.minY + 2.2,
                width: badgeRect.width - 6.0,
                height: 1.5
            )
            let trackPath = CGPath(roundedRect: trackRect, cornerWidth: 0.75, cornerHeight: 0.75, transform: nil)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.28).cgColor)
            ctx.addPath(trackPath)
            ctx.fillPath()

            let fillRect = CGRect(
                x: trackRect.minX,
                y: trackRect.minY,
                width: max(2.0, trackRect.width * bottomProgress),
                height: trackRect.height
            )
            let fillBarPath = CGPath(roundedRect: fillRect, cornerWidth: 0.75, cornerHeight: 0.75, transform: nil)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(fillBarPath)
            ctx.fillPath()
        }
    }

    private static func barHeights(for state: VisualState) -> [CGFloat] {
        switch state {
        case .idle:
            return [3.8, 7.0, 10.4, 7.0, 3.8]
        case .loading:
            return [3.4, 6.0, 8.4, 6.0, 3.4]
        case .error:
            return [4.0, 6.0, 9.2, 6.0, 4.0]
        case .recording(let level):
            let clamped = CGFloat(min(1.0, max(0.08, level * 2.4)))
            return [
                3.4 + clamped * 4.4,
                4.6 + clamped * 6.0,
                5.8 + clamped * 5.0,
                4.6 + clamped * 6.2,
                3.4 + clamped * 4.6
            ]
        case .processing(let phase):
            return (0..<5).map { idx in
                let wave = (sin(phase + Double(idx) * 0.85) + 1.0) * 0.5
                return 3.4 + CGFloat(wave) * 7.0
            }
        }
    }
}
