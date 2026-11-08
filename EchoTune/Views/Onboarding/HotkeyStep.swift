//
//  HotkeyStep.swift
//  EchoTune
//
//  Onboarding 7.5.1: press-to-test dictation key, patterned after
//  superwhisper / Speakly's shortcut test. The current key shows as a large
//  keycap on the left, lights up violet while held, and a Change option
//  rebinds it live.
//

import SwiftUI

struct HotkeyStep: View {
    let onNext: () -> Void

    @State private var isKeyPressed = false
    @State private var didTestKey = false
    @State private var isCapturing = false
    @State private var captureHint = ""
    @State private var savedFlash = false
    @State private var eventMonitor: Any?
    @State private var currentKeyCode: UInt32 = 58
    @State private var currentModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.option.rawValue)
    @State private var shakeKeycap = false

    private let shortcutManager = ShortcutManager.shared

    private var keySymbol: String {
        Self.symbol(for: currentKeyCode, modifiers: currentModifiers)
    }

    private var keyName: String {
        switch currentKeyCode {
        case 58, 61: return "Option key"
        case 59, 62: return "Control key"
        case 55, 54: return "Command key"
        case 63: return "fn / Globe key"
        case 56, 60: return "Shift key"
        default: return shortcutManager.getCurrentShortcutString()
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                OnboardingTheme.HeaderIconChip(systemName: "keyboard")

                Text("Press to test your dictation key")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("onboarding.hotkey.title")

                Text(isCapturing
                     ? "Press the key you want to use as your trigger — hold it to test."
                     : "Hold \(keyName) anywhere while this window is frontmost. \(didTestKey ? "Nice — that’s your key." : "Do you see it turn purple while pressing?")")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .animation(.easeInOut(duration: 0.2), value: didTestKey)
            }
            .padding(.top, 16)

            HStack(spacing: 40) {
                keycapView
                    .accessibilityIdentifier("onboarding.hotkey.keycap")

                VStack(alignment: .leading, spacing: 14) {
                    if isCapturing {
                        Label(captureHint.isEmpty ? "Listening for a key…" : captureHint,
                              systemImage: "waveform.badge.mic")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(OnboardingTheme.keyHighlight)
                            .accessibilityIdentifier("onboarding.hotkey.captureHint")

                        Button("Cancel") { endCapture() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Button(action: beginCapture) {
                            Label("Change key", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(OnboardingTheme.accent)
                        .controlSize(.regular)
                        .accessibilityIdentifier("onboarding.hotkey.changeButton")

                        Text(didTestKey
                             ? "Tested and working."
                             : "You can also change it later in Settings.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if savedFlash {
                        Label("Shortcut saved", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                            .transition(.opacity)
                            .accessibilityIdentifier("onboarding.hotkey.savedLabel")
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: onNext) {
                Text("Yes, continue")
                    .frame(width: 200)
            }
            .buttonStyle(GradientProminentButtonStyle())
            .controlSize(.large)
            .accessibilityIdentifier("onboarding.hotkey.continueButton")
            .padding(.bottom, 20)
        }
        .onAppear {
            currentKeyCode = shortcutManager.currentShortcutKeyCode
            currentModifiers = shortcutManager.currentShortcutModifiers
            installMonitor()
        }
        .onDisappear {
            removeMonitor()
        }
    }

    // MARK: - Keycap

    private var keycapView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isKeyPressed
                            ? [OnboardingTheme.keyHighlight, OnboardingTheme.keyHighlight.opacity(0.75)]
                            : [Color(NSColor.controlBackgroundColor), Color(NSColor.controlBackgroundColor).opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: isKeyPressed
                        ? OnboardingTheme.keyHighlight.opacity(0.55)
                        : Color.black.opacity(0.12),
                        radius: isKeyPressed ? 18 : 8, x: 0, y: isKeyPressed ? 2 : 5)

            Text(isCapturing ? "···" : keySymbol)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(isKeyPressed ? .white : .primary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .frame(width: 150, height: 150)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isKeyPressed
                        ? OnboardingTheme.keyHighlight.opacity(0.9)
                        : Color.primary.opacity(0.12),
                    lineWidth: isKeyPressed ? 2.5 : 1.5
                )
        )
        .scaleEffect(isKeyPressed ? 1.04 : 1.0)
        .offset(x: shakeKeycap ? -8 : 0)
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isKeyPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: shakeKeycap)
    }

    // MARK: - Event monitor

    private func installMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { event in
            if event.type == .flagsChanged {
                handleFlagsChanged(event)
            } else if isCapturing, event.type == .keyDown {
                handleCaptureKeyDown(event)
            } else if event.type == .keyDown {
                highlightIfMatch(event)
            } else if event.type == .keyUp {
                isKeyPressed = false
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        if isCapturing {
            captureModifier(event)
            return
        }

        let modifierOnlyKeyCodes: Set<UInt32> = [58, 61, 59, 62, 55, 54, 63, 56, 60]
        if modifierOnlyKeyCodes.contains(currentKeyCode) {
            let mask = currentModifiers == 0
                ? UInt32.max
                : currentModifiers
            let pressed = UInt32(event.modifierFlags.rawValue) & mask != 0
            if pressed {
                registerTest()
            }
            isKeyPressed = pressed
        } else {
            isKeyPressed = UInt32(event.modifierFlags.rawValue) & currentModifiers != 0 && currentModifiers != 0
        }
    }

    private func highlightIfMatch(_ event: NSEvent) {
        let modifiers = UInt32(event.modifierFlags.rawValue) & Self.modifierMask
        if UInt32(event.keyCode) == currentKeyCode && modifiers == currentModifiers {
            registerTest()
            isKeyPressed = true
        }
    }

    private func registerTest() {
        if !didTestKey {
            didTestKey = true
            OnboardingSound.play(.confirm)
        }
    }

    // MARK: - Capture

    private func beginCapture() {
        isCapturing = true
        captureHint = ""
        savedFlash = false
    }

    private func endCapture() {
        isCapturing = false
        captureHint = ""
    }

    private func captureModifier(_ event: NSEvent) {
        // Match on modifier flags, not event.keyCode: synthesized and some
        // real flagsChanged events carry a zero/absent keyCode.
        let flags = UInt32(event.modifierFlags.rawValue)

        let candidates: [(bit: UInt32, keyCode: UInt32, label: String)] = [
            (UInt32(NSEvent.ModifierFlags.option.rawValue), 58, "option"),
            (UInt32(NSEvent.ModifierFlags.control.rawValue), 59, "control"),
            (UInt32(NSEvent.ModifierFlags.command.rawValue), 55, "command"),
            (UInt32(NSEvent.ModifierFlags.function.rawValue), 63, "fn")
        ]

        var matched: (bit: UInt32, keyCode: UInt32, label: String)?
        for candidate in candidates where flags & candidate.bit != 0 {
            if matched != nil {
                // More than one modifier held — ambiguous, wait for a cleaner press.
                return
            }
            matched = candidate
        }

        guard let match = matched else { return }

        commitShortcut(keyCode: match.keyCode, modifiers: match.bit)
    }

    private func handleCaptureKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 {
            endCapture()
            return
        }

        let modifiers = UInt32(event.modifierFlags.rawValue) & Self.modifierMask
        guard modifiers != 0 else {
            rejectCapture()
            return
        }

        commitShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    private func rejectCapture() {
        captureHint = "Add a modifier key (⌘ ⌃ ⌥ ⇧ or fn)."
        shakeKeycap = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            shakeKeycap = false
        }
    }

    private func commitShortcut(keyCode: UInt32, modifiers: UInt32) {
        shortcutManager.updateShortcut(keyCode: keyCode, modifiers: modifiers)
        currentKeyCode = keyCode
        currentModifiers = modifiers
        endCapture()
        didTestKey = false
        savedFlash = true
        OnboardingSound.play(.pop)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { savedFlash = false }
        }
    }

    // MARK: - Key display

    private static let modifierMask: UInt32 = {
        UInt32(NSEvent.ModifierFlags.command.rawValue |
               NSEvent.ModifierFlags.shift.rawValue |
               NSEvent.ModifierFlags.control.rawValue |
               NSEvent.ModifierFlags.option.rawValue)
    }()

    private static func symbol(for keyCode: UInt32, modifiers: UInt32) -> String {
        switch keyCode {
        case 58, 61: return "⌥"
        case 59, 62: return "⌃"
        case 55, 54: return "⌘"
        case 56, 60: return "⇧"
        case 63: return "fn"
        default:
            let prefix = ShortcutManager().modifierFlagsToString(modifiers)
            let letter = Self.letter(for: keyCode)
            return "\(prefix)\(letter)"
        }
    }

    private static func letter(for keyCode: UInt32) -> String {
        let letters: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M", 122: "F1", 120: "F2", 99: "F3",
            118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
            109: "F10", 103: "F11", 111: "F12"
        ]
        return letters[keyCode] ?? "?"
    }
}
