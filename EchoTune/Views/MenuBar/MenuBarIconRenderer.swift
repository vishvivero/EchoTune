//
//  MenuBarIconRenderer.swift
//  EchoTune
//
//  Renders a pure-white, zero-color 22x22pt (@2x 44x44px concrete NSBitmapImageRep)
//  rounded-square menu bar badge with the EchoTune waveform centered inside.
//  Uses pure white RGB (1, 1, 1) with a subtle frosted-white interior (alpha = 0.24)
//  so there is zero color tint while every pixel inside the square stays well
//  above macOS 26 ControlCenter's hit-test alpha threshold.
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
            drawWhiteSquareBadge(in: CGRect(origin: .zero, size: canvasSize), state: state, ctx: ctx)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: canvasSize)
        image.addRepresentation(rep)
        image.isTemplate = false
        image.accessibilityDescription = "EchoTune"
        return image
    }

    private static func drawWhiteSquareBadge(in rect: CGRect, state: VisualState, ctx: CGContext) {
        let badgeRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let radius: CGFloat = 4.8

        // 1. Subtle frosted-white interior (RGB 1,1,1 @ 0.22 alpha):
        //    No color at all — looks like a clean translucent white glass pill
        //    in the menu bar while giving ControlCenter a 100% solid hit-test box.
        let fillPath = CGPath(
            roundedRect: badgeRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.22))
        ctx.addPath(fillPath)
        ctx.fillPath()

        // 2. Crisp pure-white rounded-square outline
        let strokeRect = badgeRect.insetBy(dx: 0.7, dy: 0.7)
        let strokePath = CGPath(
            roundedRect: strokeRect,
            cornerWidth: radius - 0.4,
            cornerHeight: radius - 0.4,
            transform: nil
        )
        ctx.setStrokeColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.94))
        ctx.setLineWidth(1.4)
        ctx.addPath(strokePath)
        ctx.strokePath()

        // 3. Pure-white EchoTune waveform logo bars centered inside
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

        let barWidth: CGFloat = 1.85
        let gap: CGFloat = 1.2
        let count = heights.count
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        let startX = badgeRect.midX - totalWidth / 2.0
        let centerY = hasBottomBar ? badgeRect.midY + 1.0 : badgeRect.midY

        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        for (idx, rawH) in heights.enumerated() {
            let maxH: CGFloat = hasBottomBar ? 8.8 : 11.0
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

        // 4. White bottom progress line when loading a model
        if hasBottomBar {
            let trackRect = CGRect(
                x: badgeRect.minX + 3.0,
                y: badgeRect.minY + 2.2,
                width: badgeRect.width - 6.0,
                height: 1.5
            )
            let trackPath = CGPath(roundedRect: trackRect, cornerWidth: 0.75, cornerHeight: 0.75, transform: nil)
            ctx.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.35))
            ctx.addPath(trackPath)
            ctx.fillPath()

            let fillRect = CGRect(
                x: trackRect.minX,
                y: trackRect.minY,
                width: max(2.0, trackRect.width * bottomProgress),
                height: trackRect.height
            )
            let fillBarPath = CGPath(roundedRect: fillRect, cornerWidth: 0.75, cornerHeight: 0.75, transform: nil)
            ctx.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
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
