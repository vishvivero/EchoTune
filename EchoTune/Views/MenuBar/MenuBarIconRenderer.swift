//
//  MenuBarIconRenderer.swift
//  EchoTune
//
//  Renders a full-height 22x22pt (@2x 44x44px concrete NSBitmapImageRep)
//  rounded-square menu bar badge containing the live EchoTune waveform.
//  Because the 20x20pt rounded square has 100% solid alpha (alpha = 1.0) and is
//  backed by a concrete bitmap rep (not a lazy drawingHandler closure), macOS 26
//  ControlCenter's NSSceneStatusItem hit-tests the entire square reliably.
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
            drawBadge(in: CGRect(origin: .zero, size: canvasSize), state: state, ctx: ctx)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        image.isTemplate = false
        image.accessibilityDescription = "EchoTune"
        return image
    }

    private static func drawBadge(in rect: CGRect, state: VisualState, ctx: CGContext) {
        // Full menu-bar-height 20x20pt rounded squircle centered inside 22x22pt canvas
        let badgeRect = rect.insetBy(dx: 1.0, dy: 1.0)
        let badgeRadius: CGFloat = 5.2
        let badgePath = CGPath(
            roundedRect: badgeRect,
            cornerWidth: badgeRadius,
            cornerHeight: badgeRadius,
            transform: nil
        )

        // 1. Solid rounded-square background fill (100% opaque for reliable click hit-testing)
        let (topColor, bottomColor, strokeColor, barColor) = palette(for: state)
        ctx.saveGState()
        ctx.addPath(badgePath)
        ctx.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
            locations: [0.0, 1.0]
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: badgeRect.midX, y: badgeRect.maxY),
                end: CGPoint(x: badgeRect.midX, y: badgeRect.minY),
                options: []
            )
        } else {
            ctx.setFillColor(topColor.cgColor)
            ctx.fill(badgeRect)
        }
        ctx.restoreGState()

        // Subtle crisp border around the square
        let borderRect = badgeRect.insetBy(dx: 0.5, dy: 0.5)
        let borderPath = CGPath(
            roundedRect: borderRect,
            cornerWidth: badgeRadius - 0.3,
            cornerHeight: badgeRadius - 0.3,
            transform: nil
        )
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(1.0)
        ctx.addPath(borderPath)
        ctx.strokePath()

        // 2. Waveform bars centered inside the rounded square
        let heights = barHeights(for: state)
        let hasBottomBar: Bool
        let bottomProgress: CGFloat
        if case .loading(let p) = state {
            hasBottomBar = true
            bottomProgress = CGFloat(min(1.0, max(0.10, p)))
        } else {
            hasBottomBar = false
            bottomProgress = 0
        }

        let barWidth: CGFloat = 1.9
        let gap: CGFloat = 1.35
        let count = heights.count
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        let startX = badgeRect.midX - totalWidth / 2.0
        let centerY = hasBottomBar ? badgeRect.midY + 1.2 : badgeRect.midY

        ctx.setFillColor(barColor.cgColor)
        for (idx, rawH) in heights.enumerated() {
            let maxH: CGFloat = hasBottomBar ? 9.5 : 11.8
            let h = max(2.8, min(maxH, rawH))
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

        // 3. Bottom progress bar inside the rounded square when downloading/warming model
        if hasBottomBar {
            let trackRect = CGRect(
                x: badgeRect.minX + 3.0,
                y: badgeRect.minY + 2.2,
                width: badgeRect.width - 6.0,
                height: 1.8
            )
            let trackPath = CGPath(roundedRect: trackRect, cornerWidth: 0.9, cornerHeight: 0.9, transform: nil)
            ctx.setFillColor(barColor.withAlphaComponent(0.28).cgColor)
            ctx.addPath(trackPath)
            ctx.fillPath()

            let fillRect = CGRect(
                x: trackRect.minX,
                y: trackRect.minY,
                width: max(2.0, trackRect.width * bottomProgress),
                height: trackRect.height
            )
            let fillPath = CGPath(roundedRect: fillRect, cornerWidth: 0.9, cornerHeight: 0.9, transform: nil)
            ctx.setFillColor(barColor.cgColor)
            ctx.addPath(fillPath)
            ctx.fillPath()
        }
    }

    private static func palette(for state: VisualState) -> (top: NSColor, bottom: NSColor, stroke: NSColor, bars: NSColor) {
        switch state {
        case .idle:
            // Deep slate-pine rounded square with EchoTune cyan-white waveform
            return (
                top: NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.22, alpha: 1.0),
                bottom: NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.14, alpha: 1.0),
                stroke: NSColor(calibratedRed: 0.44, green: 0.81, blue: 0.92, alpha: 0.55),
                bars: NSColor(calibratedRed: 0.52, green: 0.87, blue: 0.97, alpha: 1.0)
            )
        case .recording:
            return (
                top: NSColor(calibratedRed: 0.95, green: 0.26, blue: 0.24, alpha: 1.0),
                bottom: NSColor(calibratedRed: 0.78, green: 0.14, blue: 0.14, alpha: 1.0),
                stroke: NSColor(calibratedWhite: 1.0, alpha: 0.35),
                bars: NSColor.white
            )
        case .processing:
            return (
                top: NSColor(calibratedRed: 0.18, green: 0.62, blue: 0.78, alpha: 1.0),
                bottom: NSColor(calibratedRed: 0.11, green: 0.44, blue: 0.60, alpha: 1.0),
                stroke: NSColor(calibratedWhite: 1.0, alpha: 0.35),
                bars: NSColor.white
            )
        case .loading:
            return (
                top: NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.27, alpha: 1.0),
                bottom: NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.18, alpha: 1.0),
                stroke: NSColor(calibratedRed: 0.96, green: 0.65, blue: 0.20, alpha: 0.65),
                bars: NSColor(calibratedRed: 0.98, green: 0.76, blue: 0.32, alpha: 1.0)
            )
        case .error:
            return (
                top: NSColor(calibratedRed: 0.94, green: 0.52, blue: 0.14, alpha: 1.0),
                bottom: NSColor(calibratedRed: 0.80, green: 0.36, blue: 0.08, alpha: 1.0),
                stroke: NSColor(calibratedWhite: 1.0, alpha: 0.35),
                bars: NSColor.white
            )
        }
    }

    private static func barHeights(for state: VisualState) -> [CGFloat] {
        switch state {
        case .idle:
            return [4.2, 7.6, 11.2, 7.6, 4.2]
        case .loading:
            return [3.8, 6.6, 9.2, 6.6, 3.8]
        case .error:
            return [4.5, 6.5, 10.0, 6.5, 4.5]
        case .recording(let level):
            let clamped = CGFloat(min(1.0, max(0.08, level * 2.4)))
            return [
                3.6 + clamped * 4.8,
                5.0 + clamped * 6.6,
                6.2 + clamped * 5.6,
                5.0 + clamped * 6.8,
                3.6 + clamped * 5.0
            ]
        case .processing(let phase):
            return (0..<5).map { idx in
                let wave = (sin(phase + Double(idx) * 0.85) + 1.0) * 0.5
                return 3.6 + CGFloat(wave) * 7.8
            }
        }
    }
}
