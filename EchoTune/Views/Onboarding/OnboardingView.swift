//
//  OnboardingView.swift
//  EchoTune
//
//  World-class 6-step onboarding:
//  Welcome → Permissions → Setup → Live Demo → Features → Trial CTA
//

import SwiftUI
import AVFoundation

// MARK: - Brand Colors (adaptive light/dark)

private extension Color {
    static let echoPrimary = Color(red: 0.18, green: 0.72, blue: 0.83)
    static let echoAccent = Color(red: 0.49, green: 0.82, blue: 0.93)

    static let echoBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)
            : NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
    })

    static let echoSurface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })

    static let echoSurfaceHover = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1)
            : NSColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1)
    })

    static let echoTextPrimary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white
            : NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    })

    static let echoTextSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.55)
            : NSColor(red: 0.40, green: 0.42, blue: 0.46, alpha: 1)
    })

    static let echoTextTertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.35)
            : NSColor(red: 0.60, green: 0.62, blue: 0.66, alpha: 1)
    })

    static let echoBorder = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.08)
            : NSColor(red: 0.88, green: 0.89, blue: 0.90, alpha: 1)
    })
}

// MARK: - Main OnboardingView

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentStep: Int
    @State private var direction: Int = 1

    private let onboardingState = OnboardingStateStore.shared
    private static let totalSteps = 6
    private let totalSteps = Self.totalSteps

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _currentStep = State(initialValue: OnboardingStateStore.shared.resumeStep(totalSteps: Self.totalSteps))
    }

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.echoPrimary.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep(onNext: goForward)
                    case 1:
                        PermissionsStep(onNext: goForward, onBack: goBack)
                    case 2:
                        SetupStep(onNext: goForward, onBack: goBack)
                    case 3:
                        LiveDemoStep(onNext: goForward, onBack: goBack)
                    case 4:
                        PowerFeaturesStep(onNext: goForward, onBack: goBack)
                    case 5:
                        TrialCTAStep(onFinish: completeOnboarding, onBack: goBack)
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))
                .id(currentStep)

                StepIndicator(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 700, height: 650)
        .onAppear {
            onboardingState.setCurrentStep(currentStep)
        }
    }

    private func goForward() {
        direction = 1
        let nextStep = min(currentStep + 1, totalSteps - 1)
        onboardingState.setCurrentStep(nextStep)
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = nextStep
        }
    }

    private func goBack() {
        direction = -1
        let previousStep = max(currentStep - 1, 0)
        onboardingState.setCurrentStep(previousStep)
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = previousStep
        }
    }

    private func completeOnboarding() {
        onboardingState.completeOnboarding()
        NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
        onComplete()
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Color.echoPrimary : Color.echoTextTertiary.opacity(0.5))
                    .frame(width: index == currentStep ? 24 : 8, height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Step 1: Welcome (Emotional Hook)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct WelcomeStep: View {
    let onNext: () -> Void

    @State private var appeared = false
    @State private var wavePhase: CGFloat = 0.0
    @State private var textRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated waveform → text visual metaphor
            ZStack {
                WaveformAnimation(phase: wavePhase)
                    .frame(width: 360, height: 80)
                    .opacity(appeared ? 0.6 : 0)
                    .blur(radius: textRevealed ? 8 : 0)
                    .scaleEffect(textRevealed ? 0.8 : 1.0)

                AppIconView()
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1.0 : 0)
            }

            Spacer().frame(height: 36)

            // Bold emotional headline
            Text("Stop typing.\nStart talking.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 14)

            Spacer().frame(height: 14)

            // Pain point subtext
            Text("Your voice is 3× faster than your keyboard.\nEchoTune turns speech into text, instantly.")
                .font(.system(size: 16, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundColor(.echoTextSecondary)
                .lineSpacing(3)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 10)

            Spacer()

            // CTA
            PrimaryButton(title: "Get Started", action: onNext)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 16)

            Spacer().frame(height: 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                appeared = true
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 1.2).delay(1.5)) {
                textRevealed = true
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Step 2: Permissions (Guided Setup)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct PermissionsStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @StateObject private var permissions = PermissionsManager.shared

    @State private var appeared = false
    @State private var pollTimer: Timer?

    private var requiredPermissionsGranted: Bool {
        permissions.hasMicrophonePermission && permissions.hasAccessibilityPermission
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            BackButton(action: onBack)

            Spacer().frame(height: 8)

            Text("A few quick permissions")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)

            Spacer().frame(height: 6)

            Text("Each button opens the exact macOS privacy pane. Enable EchoTune there, then come back here.")
                .font(.system(size: 14))
                .foregroundColor(.echoTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 72)

            Spacer().frame(height: 32)

            // Permission cards
            VStack(spacing: 14) {
                OnboardingPermissionCard(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    subtitle: "Approve the system prompt so EchoTune can hear your voice",
                    isGranted: permissions.hasMicrophonePermission,
                    isRequired: true,
                    onGrant: {
                        permissions.requestMicrophonePermission { _ in
                            permissions.checkMicrophonePermission()
                        }
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                OnboardingPermissionCard(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    subtitle: permissions.accessibilityInlineInstructions,
                    isGranted: permissions.hasAccessibilityPermission,
                    isRequired: true,
                    onGrant: {
                        permissions.requestAccessibilityPermission()
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                OnboardingPermissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    subtitle: permissions.screenRecordingInlineInstructions,
                    isGranted: permissions.hasScreenRecordingPermission,
                    isRequired: false,
                    onGrant: {
                        OnboardingStateStore.shared.setCurrentStep(1)
                        permissions.requestScreenRecordingPermission()
                    }
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
            }
            .padding(.horizontal, 48)

            if !permissions.hasAccessibilityPermission || !permissions.hasScreenRecordingPermission {
                PermissionReturnHint(
                    showAccessibilityHint: !permissions.hasAccessibilityPermission,
                    showScreenRecordingHint: !permissions.hasScreenRecordingPermission
                )
                .padding(.horizontal, 48)
                .padding(.top, 14)
            }

            Spacer()

            // Continue
            PrimaryButton(
                title: "Continue",
                action: onNext,
                disabled: !requiredPermissionsGranted
            )

            if !requiredPermissionsGranted {
                Text("Grant microphone & accessibility to continue")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 48)
        }
        .onAppear {
            appeared = true
            permissions.checkAllPermissions()
            startPolling()
        }
        .onChange(of: requiredPermissionsGranted) { _, granted in
            if granted {
                stopPolling()
            } else {
                startPolling()
            }
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            permissions.checkAllPermissions()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

private struct PermissionReturnHint: View {
    let showAccessibilityHint: Bool
    let showScreenRecordingHint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("When System Settings opens:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.echoTextPrimary)

            if showAccessibilityHint {
                Text("1. In Accessibility, turn on EchoTune.")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextSecondary)
            }

            if showScreenRecordingHint {
                Text(showAccessibilityHint ? "2. In Screen Recording, enable EchoTune for richer app-aware context." : "1. In Screen Recording, enable EchoTune for richer app-aware context.")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextSecondary)
            }

            Text("Return to EchoTune afterward. Permission status refreshes automatically when the app becomes active again.")
                .font(.system(size: 11))
                .foregroundColor(.echoTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.echoSurface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.echoBorder, lineWidth: 1)
        )
    }
}

// MARK: - Onboarding Permission Card

private struct OnboardingPermissionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let isRequired: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isGranted ? Color.green.opacity(0.12) : Color.echoPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: isGranted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 17))
                    .foregroundColor(isGranted ? .green : .echoPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.echoTextPrimary)

                    if !isRequired {
                        Text("Optional")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.echoTextTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.echoSurfaceHover)
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
            }

            Spacer()

            if isGranted {
                Text("Granted")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Button(action: onGrant) {
                    Text("Grant")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.echoPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isGranted ? Color.green.opacity(0.3) : Color.echoBorder, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isGranted)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Step 3: Setup (Mic + Model + Shortcut)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct SetupStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var modelManager = ModelManager.shared

    @State private var selectedMicID: String?
    @State private var availableDevices: [AudioDevice] = []
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadFailed = false
    @State private var isVerifyingModel = false
    @State private var modelReady = false
    @State private var modelErrorMessage: String?
    @State private var appeared = false

    // Audio level monitoring
    @State private var audioLevelTimer: Timer?
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.05, count: 20)

    // Shortcut recording
    @State private var isRecordingShortcut = false
    @State private var recordedShortcutDisplay = ""
    @State private var currentShortcutDisplay = ShortcutManager.shared.getCurrentShortcutString()
    @State private var shortcutMonitor: Any?

    private var recommendedModel: AIModel? {
        modelManager.availableModels.first { $0.id == "base" } ??
        modelManager.availableModels.first { !$0.isBuiltIn }
    }

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)

            Spacer().frame(height: 8)

            Text("Quick Setup")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)

            Spacer().frame(height: 6)

            Text("Configure your microphone, shortcut, and model.")
                .font(.system(size: 14))
                .foregroundColor(.echoTextSecondary)

            Spacer().frame(height: 28)

            VStack(spacing: 14) {
                // 1. Microphone with live level
                SetupCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    subtitle: "Select your input device"
                ) {
                    VStack(alignment: .trailing, spacing: 8) {
                        Menu {
                            ForEach(availableDevices) { device in
                                Button(action: {
                                    selectedMicID = device.id
                                    audioManager.selectAudioDevice(id: device.id)
                                }) {
                                    HStack {
                                        Text(device.name + (device.isDefault ? " (Default)" : ""))
                                        if selectedMicID == device.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedDeviceName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.echoTextPrimary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.echoTextTertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.echoSurfaceHover)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.echoBorder, lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        // Live audio level bars
                        AudioLevelBars(levels: audioLevels)
                            .frame(height: 18)
                            .frame(maxWidth: 140)
                    }
                }

                // 2. Shortcut
                SetupCard(
                    icon: "keyboard.fill",
                    title: "Shortcut",
                    subtitle: isRecordingShortcut ? "Press your desired shortcut…" : "Press to start/stop dictation"
                ) {
                    if isRecordingShortcut {
                        HStack(spacing: 6) {
                            Text(recordedShortcutDisplay.isEmpty ? "Waiting…" : recordedShortcutDisplay)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.echoAccent)

                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.echoAccent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.echoAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Button(action: { startRecordingShortcut() }) {
                            HStack(spacing: 6) {
                                Text(currentShortcutDisplay)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.echoTextPrimary)
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundColor(.echoTextTertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.echoSurfaceHover)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.echoBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 3. Model
                SetupCard(
                    icon: "cpu.fill",
                    title: "Transcription Model",
                    subtitle: modelSubtitle
                ) {
                    if modelReady {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("Ready")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                    } else if !modelManager.isReady || isVerifyingModel {
                        VStack(alignment: .trailing, spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.echoPrimary)
                            Text(modelManager.isReady ? "Verifying…" : "Checking…")
                                .font(.system(size: 10))
                                .foregroundColor(.echoTextTertiary)
                        }
                    } else if isDownloading {
                        VStack(alignment: .trailing, spacing: 4) {
                            ProgressView(value: downloadProgress)
                                .progressViewStyle(.linear)
                                .tint(Color.echoPrimary)
                                .frame(width: 120)
                            Text("\(Int(downloadProgress * 100))%")
                                .font(.system(size: 10))
                                .foregroundColor(.echoTextTertiary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button(action: downloadModel) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Download")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.echoPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.echoPrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)

                            if let model = recommendedModel {
                                Text(formatSize(model.size))
                                    .font(.system(size: 10))
                                    .foregroundColor(.echoTextTertiary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 48)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            if let modelErrorMessage, !modelReady {
                Text(modelErrorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.top, 10)
                    .padding(.horizontal, 48)
            }

            Spacer()

            PrimaryButton(title: "Continue", action: onNext)

            if !modelReady && !isDownloading && !isVerifyingModel {
                Text("You can skip — Apple Speech will be used instead")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 48)
        }
        .onAppear {
            loadDevices()
            startAudioLevelMonitoring()
            refreshModelStatus()
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
        .onReceive(modelManager.$isReady) { _ in
            refreshModelStatus()
        }
        .onDisappear {
            audioLevelTimer?.invalidate()
            stopRecordingShortcutIfNeeded()
        }
    }

    // MARK: - Helpers

    private var selectedDeviceName: String {
        if let id = selectedMicID,
           let device = availableDevices.first(where: { $0.id == id }) {
            return device.name + (device.isDefault ? " (Default)" : "")
        }
        return "Select Microphone"
    }

    private var modelSubtitle: String {
        if modelReady { return "Offline transcription is ready to use" }
        if !modelManager.isReady { return "Checking installed models on this Mac" }
        if isDownloading { return "Downloading offline transcription model" }
        if isVerifyingModel { return "Verifying model files and loading Whisper" }
        if downloadFailed { return "Model setup failed — try again or skip" }
        return "Offline transcription with Whisper"
    }

    private func loadDevices() {
        availableDevices = audioManager.getAvailableInputDevices()
        if selectedMicID == nil,
           let defaultDevice = availableDevices.first(where: { $0.isDefault }) {
            selectedMicID = defaultDevice.id
        } else if selectedMicID == nil, let first = availableDevices.first {
            selectedMicID = first.id
        }
    }

    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            let level = CGFloat(audioManager.audioLevel)
            withAnimation(.easeOut(duration: 0.08)) {
                audioLevels.removeFirst()
                audioLevels.append(max(0.05, level * 10))
            }
        }
    }

    private func downloadModel() {
        guard modelManager.isReady else {
            modelErrorMessage = "EchoTune is still checking installed models. Wait a moment, then try again."
            return
        }

        guard let model = recommendedModel else {
            modelErrorMessage = "No recommended offline model is available right now."
            return
        }

        if let installedModel = modelManager.installedModel(withID: model.id),
           modelManager.isInstalledAndUsable(model) {
            verifyModel(installedModel)
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadFailed = false
        modelReady = false
        modelErrorMessage = nil

        modelManager.downloadModel(model, progressHandler: { progress in
            DispatchQueue.main.async {
                self.downloadProgress = progress
            }
        }) { result in
            DispatchQueue.main.async {
                self.isDownloading = false
                switch result {
                case .success:
                    if let installedModel = self.modelManager.installedModel(withID: model.id) {
                        self.verifyModel(installedModel)
                    } else {
                        self.downloadFailed = true
                        self.modelErrorMessage = "The download finished, but EchoTune could not find the installed model files."
                    }
                case .failure:
                    self.downloadFailed = true
                    self.modelErrorMessage = "Model download failed. Check your internet connection, then try again."
                }
            }
        }
    }

    private func refreshModelStatus() {
        guard let recommendedModel else {
            modelReady = false
            modelErrorMessage = "No recommended offline model is available right now."
            return
        }

        guard modelManager.isReady else {
            modelReady = false
            if !isDownloading {
                modelErrorMessage = nil
            }
            return
        }

        guard let installedModel = modelManager.installedModel(withID: recommendedModel.id),
              modelManager.isInstalledAndUsable(recommendedModel) else {
            modelReady = false
            if !downloadFailed && !isDownloading {
                modelErrorMessage = nil
            }
            return
        }

        if !modelReady && !isVerifyingModel && !isDownloading {
            verifyModel(installedModel)
        }
    }

    private func verifyModel(_ model: AIModel) {
        guard !isVerifyingModel else { return }

        isVerifyingModel = true
        modelReady = false
        downloadFailed = false
        modelErrorMessage = nil

        guard modelManager.setCurrentModel(model) else {
            isVerifyingModel = false
            modelErrorMessage = "EchoTune could not select \(model.name) as the active transcription model."
            return
        }

        WhisperEngine.shared.loadModel(model) { result in
            DispatchQueue.main.async {
                self.isVerifyingModel = false

                switch result {
                case .success:
                    self.modelReady = true
                    self.modelErrorMessage = nil
                case .failure(let error):
                    self.modelReady = false
                    self.downloadFailed = true
                    self.modelErrorMessage = "EchoTune downloaded \(model.name), but Whisper could not load it: \(error.localizedDescription)"
                }
            }
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_024 / 1_024
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
    }

    // MARK: - Shortcut Recording

    private func startRecordingShortcut() {
        isRecordingShortcut = true
        recordedShortcutDisplay = ""

        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])

            if event.type == .flagsChanged {
                let modStr = ShortcutManager.shared.modifierFlagsToString(UInt32(modifiers.rawValue))
                if !modStr.isEmpty {
                    self.recordedShortcutDisplay = modStr + "…"
                }
                return event
            }

            let modRaw = UInt32(modifiers.rawValue)

            if keyCode == 53 {
                self.stopRecordingShortcutIfNeeded()
                return nil
            }

            let isFnKey = (keyCode >= 96 && keyCode <= 122) || keyCode == 59 || keyCode == 58
            if modRaw == 0 && !isFnKey {
                return event
            }

            ShortcutManager.shared.updateShortcut(keyCode: UInt32(keyCode), modifiers: modRaw)
            ShortcutManager.shared.unregisterGlobalShortcut()
            ShortcutManager.shared.registerGlobalShortcut()

            self.currentShortcutDisplay = ShortcutManager.shared.getCurrentShortcutString()
            self.stopRecordingShortcutIfNeeded()
            return nil
        }
    }

    private func stopRecordingShortcutIfNeeded() {
        isRecordingShortcut = false
        recordedShortcutDisplay = ""
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Step 4: Live Demo (THE WOW MOMENT)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct LiveDemoStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared

    @State private var appeared = false
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var displayedText = ""
    @State private var resultCaption = ""
    @State private var resultIsError = false
    @State private var isTranscribing = false
    @State private var showResult = false
    @State private var recordingSeconds: Int = 0
    @State private var recordingTimer: Timer?
    @State private var audioLevels: [CGFloat] = Array(repeating: 0.05, count: 30)
    @State private var audioLevelTimer: Timer?
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)

            Spacer().frame(height: 8)

            Text("Try it now")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 6)

            Text(isRecording ? "Listening… speak naturally" : (showResult ? "See? That's EchoTune." : "Tap the button and say something!"))
                .font(.system(size: 14))
                .foregroundColor(isRecording ? .echoPrimary : .echoTextSecondary)
                .animation(.easeInOut(duration: 0.3), value: isRecording)
                .animation(.easeInOut(duration: 0.3), value: showResult)

            Spacer().frame(height: 32)

            if showResult {
                // Transcribed text result with typing effect
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.echoSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke((resultIsError ? Color.red : Color.echoPrimary).opacity(0.3), lineWidth: 1)
                            )

                        VStack(spacing: 12) {
                            Image(systemName: resultIsError ? "exclamationmark.triangle.fill" : "text.quote")
                                .font(.system(size: 20))
                                .foregroundColor(resultIsError ? .red : .echoPrimary)

                            Text(displayedText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.echoTextPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .frame(minHeight: 60)

                            if displayedText.count == transcribedText.count && !resultCaption.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: resultIsError ? "info.circle" : "sparkles")
                                        .font(.system(size: 11))
                                    Text(resultCaption)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(resultIsError ? .red : .echoPrimary)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding(.vertical, 24)
                    }
                    .frame(maxWidth: 440)
                    .frame(minHeight: 140)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Try again button
                    Button(action: resetDemo) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                            Text("Try Again")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.echoTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 48)
            } else {
                // Recording visualizer area
                VStack(spacing: 24) {
                    if isRecording {
                        // Audio waveform visualization
                        AudioLevelWaveform(levels: audioLevels)
                            .frame(height: 60)
                            .frame(maxWidth: 300)
                            .transition(.opacity)

                        Text("\(recordingSeconds)s")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.echoTextTertiary)
                    } else if isTranscribing {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.echoPrimary)

                        Text("Transcribing…")
                            .font(.system(size: 13))
                            .foregroundColor(.echoTextSecondary)
                    } else {
                        // Placeholder encouragement
                        Text("🎤")
                            .font(.system(size: 40))
                            .opacity(0.6)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 48)
            }

            Spacer().frame(height: 28)

            // Big record button (only show when not displaying result)
            if !showResult {
                Button(action: toggleRecording) {
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .stroke(Color.echoPrimary.opacity(isRecording ? 0.3 : 0), lineWidth: 3)
                            .frame(width: 88, height: 88)
                            .scaleEffect(pulseScale)

                        // Button background
                        Circle()
                            .fill(
                                isRecording
                                    ? LinearGradient(colors: [Color.red, Color.red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.echoPrimary, Color.echoAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: (isRecording ? Color.red : Color.echoPrimary).opacity(0.4), radius: 16, y: 6)

                        // Icon
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTranscribing)
            }

            Spacer()

            // Continue
            PrimaryButton(title: "Continue", action: onNext)
                .opacity(appeared ? 1 : 0)

            if !showResult {
                Text("You can skip this — but the wow moment is worth it!")
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
                    .padding(.top, 6)
            }

            Spacer().frame(height: 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .onDisappear {
            stopEverything()
        }
    }

    // MARK: - Recording Logic

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard let currentModel = currentModel else {
            presentDemoMessage(
                "No transcription model is selected. Go back to Setup and choose an offline model before running the demo.",
                isError: true,
                caption: "Setup required"
            )
            return
        }

        guard currentModel.category != .cloud else {
            presentDemoMessage(
                "The onboarding demo only supports Apple Speech or an offline Whisper model. Go back to Setup and install the Base model for a local demo.",
                isError: true,
                caption: "Cloud models need API keys"
            )
            return
        }

        if currentModel.isBuiltIn && !transcriptionEngine.isPermissionGranted {
            transcriptionEngine.requestPermission { granted in
                if granted {
                    self.beginRecording()
                } else {
                    self.presentDemoMessage(
                        "Speech Recognition permission is required when Apple Speech is selected. Allow it in the system prompt, or go back and install the offline Base model instead.",
                        isError: true,
                        caption: "Permission required"
                    )
                }
            }
            return
        }

        beginRecording()
    }

    private func beginRecording() {
        isRecording = true
        recordingSeconds = 0
        transcribedText = ""
        displayedText = ""
        resultCaption = ""
        resultIsError = false
        showResult = false

        // Start audio recording
        audioManager.startRecording()

        // Timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingSeconds += 1
            // Auto-stop after 15 seconds
            if recordingSeconds >= 15 {
                stopRecording()
            }
        }

        // Audio level monitoring
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            let level = CGFloat(audioManager.audioLevel)
            withAnimation(.easeOut(duration: 0.06)) {
                audioLevels.removeFirst()
                audioLevels.append(max(0.05, level * 12))
            }
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }

    private func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        audioLevelTimer?.invalidate()

        withAnimation { pulseScale = 1.0 }

        isTranscribing = true

        // Determine engine type
        let useWhisper = currentModel?.category == .local && currentModel?.isBuiltIn == false
        let engineType: AudioManager.AudioEngine = useWhisper ? .whisper : .appleSpeech
        let audioData = audioManager.stopRecording(forEngine: engineType)

        if let audioData = audioData, !audioData.isEmpty {
            performDemoTranscription(audioData: audioData)
        } else {
            isTranscribing = false
            presentDemoMessage(
                "No audio was captured. Check the selected microphone, then try again and speak a little louder.",
                isError: true,
                caption: "Recording failed"
            )
        }
    }

    private func performDemoTranscription(audioData: Data) {
        guard let currentModel = currentModel else {
            isTranscribing = false
            presentDemoMessage(
                "No transcription model is selected. Go back to Setup and choose a model before running the demo.",
                isError: true,
                caption: "Setup required"
            )
            return
        }

        if currentModel.isBuiltIn {
            transcriptionEngine.transcribeAudio(audioData) { result in
                DispatchQueue.main.async {
                    self.isTranscribing = false

                    switch result {
                    case .success(let text):
                        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if cleanedText.isEmpty {
                            self.presentDemoMessage(
                                "No words were detected. Try again, speak naturally, and stay close to the microphone.",
                                isError: true,
                                caption: "Nothing recognized"
                            )
                        } else {
                            self.presentDemoMessage(
                                cleanedText,
                                isError: false,
                                caption: "Processed with Apple Speech"
                            )
                        }
                    case .failure(let error):
                        self.presentDemoMessage(
                            self.appleSpeechErrorMessage(for: error),
                            isError: true,
                            caption: "Apple Speech could not complete the demo"
                        )
                    }
                }
            }
            return
        }

        guard let installedModel = modelManager.installedModel(withID: currentModel.id),
              modelManager.isInstalledAndUsable(currentModel) else {
            isTranscribing = false
            presentDemoMessage(
                "The selected offline model is not installed anymore. Go back to Setup and download the Base model again.",
                isError: true,
                caption: "Offline model missing"
            )
            return
        }

        guard modelManager.setCurrentModel(installedModel) else {
            isTranscribing = false
            presentDemoMessage(
                "EchoTune could not switch to \(installedModel.name). Go back to Setup and re-run model setup.",
                isError: true,
                caption: "Model selection failed"
            )
            return
        }

        WhisperEngine.shared.loadModel(installedModel) { loadResult in
            DispatchQueue.main.async {
                switch loadResult {
                case .success:
                    WhisperEngine.shared.transcribeAudio(audioData) { result in
                        DispatchQueue.main.async {
                            self.isTranscribing = false

                            switch result {
                            case .success(let transcription):
                                let cleanedText = transcription.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if cleanedText.isEmpty {
                                    self.presentDemoMessage(
                                        "No words were detected. Try again with a longer phrase and a quieter room if possible.",
                                        isError: true,
                                        caption: "Nothing recognized"
                                    )
                                } else {
                                    self.presentDemoMessage(
                                        cleanedText,
                                        isError: false,
                                        caption: "Processed with \(installedModel.name)"
                                    )
                                }
                            case .failure(let error):
                                self.presentDemoMessage(
                                    self.whisperErrorMessage(for: error, model: installedModel),
                                    isError: true,
                                    caption: "Offline transcription failed"
                                )
                            }
                        }
                    }
                case .failure(let error):
                    self.isTranscribing = false
                    self.presentDemoMessage(
                        "EchoTune downloaded \(installedModel.name), but Whisper could not load it for the demo: \(error.localizedDescription)",
                        isError: true,
                        caption: "Model load failed"
                    )
                }
            }
        }
    }

    private func showResultWithAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showResult = true
        }

        // Typing animation
        let chars = Array(transcribedText)
        for (index, _) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.025) {
                displayedText = String(chars.prefix(index + 1))
            }
        }
    }

    private func resetDemo() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showResult = false
            transcribedText = ""
            displayedText = ""
            resultCaption = ""
            resultIsError = false
            audioLevels = Array(repeating: 0.05, count: 30)
        }
    }

    private func stopEverything() {
        recordingTimer?.invalidate()
        audioLevelTimer?.invalidate()
        if isRecording {
            _ = audioManager.stopRecording()
        }
    }

    private var currentModel: AIModel? {
        modelManager.currentModel ?? modelManager.availableModels.first(where: { $0.id == "apple-speech" })
    }

    private func presentDemoMessage(_ message: String, isError: Bool, caption: String) {
        transcribedText = message
        displayedText = ""
        resultIsError = isError
        resultCaption = caption
        showResultWithAnimation()
    }

    private func appleSpeechErrorMessage(for error: TranscriptionEngine.TranscriptionError) -> String {
        switch error {
        case .permissionDenied:
            return "Speech Recognition permission is not granted. Allow it in System Settings, or use the offline Base model instead."
        case .unavailable:
            return "Apple Speech is unavailable right now on this Mac. Go back to Setup and use the offline Base model for a deterministic demo."
        case .noAudioData:
            return "No audio data reached the speech recognizer. Check the selected microphone and try again."
        case .recognitionError(let underlyingError):
            return "Apple Speech failed during transcription: \(underlyingError.localizedDescription)"
        case .audioFormatError:
            return "EchoTune could not prepare the recorded audio for Apple Speech. Try the demo again."
        case .processingError:
            return "Apple Speech could not finish processing that sample. Try again with a slightly longer phrase."
        }
    }

    private func whisperErrorMessage(for error: WhisperEngine.WhisperError, model: AIModel) -> String {
        switch error {
        case .modelNotLoaded:
            return "\(model.name) was not loaded when transcription started. Go back to Setup and re-run model setup."
        case .modelLoadFailed(let underlyingError):
            return "Whisper could not load \(model.name): \(underlyingError.localizedDescription)"
        case .transcriptionFailed(let underlyingError):
            return "Whisper failed to transcribe the recording: \(underlyingError.localizedDescription)"
        case .audioFormatError:
            return "EchoTune could not convert the recorded audio into Whisper's expected format."
        case .noAudioData:
            return "No audio data reached Whisper. Check the selected microphone and try again."
        case .modelNotFound:
            return "\(model.name) is no longer installed on this Mac. Go back to Setup and download it again."
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Step 5: Power Features (Quick Showcase)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct PowerFeaturesStep: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var appeared = false
    @State private var cardAppeared: [Bool] = [false, false, false, false]

    private let features: [(icon: String, title: String, subtitle: String, gradient: [Color])] = [
        ("brain.head.profile", "Context Aware", "Reads your screen to enhance transcription accuracy with context", [Color(red: 0.56, green: 0.36, blue: 0.90), Color(red: 0.72, green: 0.50, blue: 1.0)]),
        ("bolt.fill", "Power Modes", "Auto-switches settings per app — different rules for Slack, Docs, Code", [Color(red: 0.95, green: 0.55, blue: 0.20), Color(red: 1.0, green: 0.72, blue: 0.40)]),
        ("target", "Trigger Words", "Say magic keywords to activate AI prompts — \"fix grammar\" or \"translate\"", [Color(red: 0.20, green: 0.70, blue: 0.45), Color(red: 0.40, green: 0.85, blue: 0.60)]),
        ("lock.shield.fill", "Privacy First", "Fully offline mode available — your voice never leaves your Mac", [Color(red: 0.22, green: 0.55, blue: 0.85), Color(red: 0.40, green: 0.70, blue: 0.95)]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)

            Spacer().frame(height: 8)

            Text("You're just getting started")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 6)

            Text("EchoTune is packed with power features.")
                .font(.system(size: 14))
                .foregroundColor(.echoTextSecondary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 28)

            // Feature cards in 2×2 grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(0..<features.count, id: \.self) { index in
                    let feature = features[index]
                    FeatureShowcaseCard(
                        icon: feature.icon,
                        title: feature.title,
                        subtitle: feature.subtitle,
                        gradient: feature.gradient
                    )
                    .opacity(cardAppeared[index] ? 1 : 0)
                    .offset(y: cardAppeared[index] ? 0 : 20)
                    .scaleEffect(cardAppeared[index] ? 1.0 : 0.95)
                }
            }
            .padding(.horizontal, 48)

            Spacer()

            PrimaryButton(title: "Continue", action: onNext)

            Spacer().frame(height: 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }

            // Staggered card animations
            for i in 0..<4 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(i) * 0.12 + 0.15)) {
                    cardAppeared[i] = true
                }
            }
        }
    }
}

private struct FeatureShowcaseCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Gradient icon circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.echoTextPrimary)

            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.echoTextSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isHovered ? gradient.first!.opacity(0.4) : Color.echoBorder,
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Step 6: Trial CTA / Get Started
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct TrialCTAStep: View {
    let onFinish: () -> Void
    let onBack: () -> Void

    @State private var appeared = false
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var activationError: String?
    @State private var showLicenseField = false
    @State private var purchaseStatusMessage: String?
    @State private var purchaseStatusIsError = false
    @State private var showPurchaseSheet = false

    private let licenseManager = LicenseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)

            Spacer()

            // Checkmark / crown icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.echoPrimary.opacity(0.15), Color.echoAccent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(appeared ? 1.0 : 0.5)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.echoPrimary, Color.echoAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appeared ? 1.0 : 0.5)
            }

            Spacer().frame(height: 24)

            Text("You're all set!")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.echoTextPrimary)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 8)

            Text("Start your 7-day free trial with full access.\nNo credit card required.")
                .font(.system(size: 15))
                .foregroundColor(.echoTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 28)

            // What you get
            VStack(spacing: 8) {
                TrialFeatureRow(icon: "infinity", text: "Unlimited transcriptions")
                TrialFeatureRow(icon: "sparkles", text: "All AI models & enhancements")
                TrialFeatureRow(icon: "keyboard", text: "Global shortcut — works in any app")
                TrialFeatureRow(icon: "brain.head.profile", text: "Context-aware & Power Modes")
            }
            .padding(.horizontal, 80)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 28)

            // CTA Buttons
            VStack(spacing: 12) {
                // Primary: Start Free Trial
                Button(action: onFinish) {
                    Text(primaryButtonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 260, height: 46)
                        .background(
                            LinearGradient(
                                colors: [Color.echoPrimary, Color.echoAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.echoPrimary.opacity(0.35), radius: 16, y: 6)
                }
                .buttonStyle(.plain)

                #if APPSTORE
                Button(action: {
                    showPurchaseSheet = true
                    purchaseStatusMessage = nil
                }) {
                    Text(storeButtonTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.echoPrimary)
                }
                .buttonStyle(.plain)
                #else
                HStack(spacing: 16) {
                    Button(action: openPurchaseFlow) {
                        Text("Get License")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.echoPrimary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        activationError = nil
                        withAnimation(.easeOut(duration: 0.25)) {
                            showLicenseField.toggle()
                        }
                    }) {
                        Text(showLicenseField ? "Hide License Field" : "I have a license key")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.echoPrimary)
                    }
                    .buttonStyle(.plain)
                }

                if showLicenseField {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("XXXXX-XXXXX-XXXXX-XXXXX", text: $licenseKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 220)

                            Button(action: activateLicense) {
                                if isActivating {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.echoPrimary)
                                } else {
                                    Text("Activate")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.echoPrimary)
                            .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)
                        }

                        if let error = activationError {
                            Text(error)
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                #endif

                if let purchaseStatusMessage {
                    Text(purchaseStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(purchaseStatusIsError ? .red : .echoPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            Text(trialFooterText)
                .font(.system(size: 11))
                .foregroundColor(.echoTextTertiary)
                .padding(.bottom, 48)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PurchaseCompleted"))) { _ in
            purchaseStatusIsError = false
            purchaseStatusMessage = "Pro unlocked on this Mac. Finish setup when you're ready."
        }
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseView()
        }
    }

    private func activateLicense() {
        isActivating = true
        activationError = nil
        purchaseStatusMessage = nil

        licenseManager.activateLicense(licenseKey.uppercased()) { result in
            isActivating = false
            switch result {
            case .success:
                onFinish()
            case .failure(let error):
                activationError = error.localizedDescription
            }
        }
    }

    private func openPurchaseFlow() {
        activationError = nil
        let opened = licenseManager.openPurchaseURL()
        purchaseStatusIsError = !opened
        purchaseStatusMessage = opened
            ? "Purchase page opened in your browser. After checkout, come back here and paste your license key."
            : "EchoTune could not open the purchase page. Visit \(Constants.purchaseURL) manually to buy a license."
    }

    private var primaryButtonTitle: String {
        licenseManager.isPro ? "Finish Setup" : "Start Free Trial"
    }

    private var storeButtonTitle: String {
        licenseManager.isPro ? "Pro unlocked" : "Upgrade to Pro"
    }

    private var trialFooterText: String {
        #if APPSTORE
        return "7-day free trial • Then a one-time App Store purchase"
        #else
        return "7-day free trial • Then a one-time EchoTune license"
        #endif
    }
}

private struct TrialFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.echoPrimary)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.echoTextSecondary)

            Spacer()
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Reusable Components
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.echoPrimary, Color.echoAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .shadow(color: Color.echoPrimary.opacity(0.4), radius: 20, y: 8)

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    let heights: [CGFloat] = [18, 30, 42, 30, 18]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 6, height: heights[i])
                }
            }
        }
    }
}

private struct WaveformAnimation: View {
    var phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width

            for wave in 0..<3 {
                let amplitude: CGFloat = [20, 14, 8][wave]
                let frequency: CGFloat = [1.2, 1.8, 2.5][wave]
                let phaseShift: CGFloat = [0, 0.5, 1.0][wave]
                let opacity: Float = [0.15, 0.10, 0.06][wave]

                var path = Path()
                for x in stride(from: 0, through: width, by: 1) {
                    let relX = x / width
                    let envelope = sin(relX * .pi)
                    let y = midY + sin(relX * .pi * 2 * frequency + phase + phaseShift) * amplitude * envelope
                    if x == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(Color.echoPrimary.opacity(Double(opacity * 3))),
                    lineWidth: 2
                )
            }
        }
    }
}

// Audio level bars for mic setup
private struct AudioLevelBars: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        levels[i] > 0.3
                            ? Color.echoPrimary
                            : Color.echoPrimary.opacity(0.3)
                    )
                    .frame(width: 3, height: max(2, levels[i] * 18))
            }
        }
    }
}

// Audio waveform for live demo
private struct AudioLevelWaveform: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.echoPrimary, Color.echoAccent],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: max(4, levels[i] * 60))
            }
        }
    }
}

private struct SetupCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.echoPrimary.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.echoPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.echoTextPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.echoTextTertiary)
            }

            Spacer()

            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.echoBorder, lineWidth: 1)
        )
    }
}

// MARK: - Shared Buttons

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 220, height: 44)
                .background(
                    LinearGradient(
                        colors: disabled
                            ? [Color.echoTextTertiary, Color.echoTextTertiary]
                            : [Color.echoPrimary, Color.echoPrimary.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: disabled ? Color.clear : Color.echoPrimary.opacity(0.3), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.echoTextSecondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 48)
        .padding(.top, 28)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
        .frame(width: 700, height: 650)
}
