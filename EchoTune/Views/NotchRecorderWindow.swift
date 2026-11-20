//
//  NotchRecorderWindow.swift
//  EchoTune
//
//  Dynamic-Island-style MacBook Notch recorder panel (RecorderStyle.notch).
//  Expands smoothly from the top-center menu bar / camera-housing edge on the
//  active cursor display with concave top-edge notch ears, live waveform,
//  Voice-Command badge, and monospaced duration readout.
//

import AppKit
import Combine
import SwiftUI

struct NotchCapsuleShape: Shape {
    var earRadius: CGFloat = 10
    var bottomCornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        let e = min(earRadius, rect.width * 0.12)
        let b = min(bottomCornerRadius, rect.height * 0.65)
        var p = Path()

        // Top-left concave ear flush against screen top (y = 0 in SwiftUI coords)
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: e, y: e),
            control: CGPoint(x: e, y: 0)
        )
        // Left vertical edge down to bottom-left corner
        p.addLine(to: CGPoint(x: e, y: rect.height - b))
        p.addQuadCurve(
            to: CGPoint(x: e + b, y: rect.height),
            control: CGPoint(x: e, y: rect.height)
        )
        // Bottom edge
        p.addLine(to: CGPoint(x: rect.width - e - b, y: rect.height))
        // Bottom-right corner
        p.addQuadCurve(
            to: CGPoint(x: rect.width - e, y: rect.height - b),
            control: CGPoint(x: rect.width - e, y: rect.height)
        )
        // Right vertical edge up to top-right concave ear
        p.addLine(to: CGPoint(x: rect.width - e, y: e))
        p.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width - e, y: 0)
        )
        p.closeSubpath()
        return p
    }
}

final class NotchRecorderWindow: NSPanel {
    static let shared = NotchRecorderWindow()

    private let expandedWidth: CGFloat = 336
    private let expandedHeight: CGFloat = 42

    private init() {
        let initialRect = NSRect(x: 400, y: 800, width: 336, height: 42)
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let root = AnyView(NotchRecorderContentView())
        let hosting = TransparentHostingView(rootView: root)
        self.contentView = hosting
    }

    func show() {
        guard let screen = RecorderScreenResolver.resolveForShow() else { return }
        let frame = screen.frame
        let x = frame.midX - expandedWidth / 2
        let y = frame.maxY - expandedHeight

        let startWidth: CGFloat = 210
        let collapsedRect = NSRect(
            x: frame.midX - startWidth / 2,
            y: frame.maxY - 30,
            width: startWidth,
            height: 30
        )
        let targetRect = NSRect(x: x, y: y, width: expandedWidth, height: expandedHeight)

        if !self.isVisible {
            self.setFrame(collapsedRect, display: false)
            self.alphaValue = 0.0
            self.setIsVisible(true)
            self.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1.0)
            self.animator().setFrame(targetRect, display: true)
            self.animator().alphaValue = 1.0
        }
    }

    func hide() {
        guard self.isVisible else { return }
        self.orderOut(nil)
    }
}

struct NotchRecorderContentView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var appState = AppState.shared

    private var isVoiceTransform: Bool {
        AppCoordinator.shared.activeVoiceTransformSelection != nil
    }

    var body: some View {
        HStack(spacing: 10) {
            if isVoiceTransform {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.purple)
                    Text("Edit")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.purple.opacity(0.32))
                .clipShape(Capsule())
            } else {
                Circle()
                    .fill(appState.recordingState == .recording ? Color.red : Color.blue)
                    .frame(width: 8, height: 8)
            }

            if appState.recordingState == .recording {
                CaptureWaveformView(barCount: 18, barWidth: 2.2, barSpacing: 1.5, maxHeight: 16)
                    .frame(maxWidth: .infinity)
            } else {
                Text(appState.recordingStatusDetail ?? "Transcribing…")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }

            Text(statusTimerText)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))

            Button {
                AppCoordinator.shared.toggleDictation()
            } label: {
                Image(systemName: appState.recordingState == .processing ? "xmark" : "stop.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            NotchCapsuleShape(earRadius: 10, bottomCornerRadius: 16)
                .fill(Color.black)
                .overlay(
                    NotchCapsuleShape(earRadius: 10, bottomCornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }

    private var statusTimerText: String {
        switch appState.recordingState {
        case .recording:
            return AudioManager.formatDuration(audioManager.recordingDuration)
        case .processing:
            return "•••"
        default:
            return ""
        }
    }
}
