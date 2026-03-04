//
//  OnboardingView.swift
//  EchoTune
//
//  Comprehensive Onboarding Flow
//  Fixes applied:
//    1. Trial timing — trial starts AFTER onboarding completes
//    2. Accessibility is soft-required (skip with clipboard fallback)
//    3. Cloud transcription (Groq) shown as default; Whisper optional
//    4. Live demo routes to correct engine (Groq vs Whisper)
//    5. Launch-at-login toggle in Setup step
//    6. Language picker in Setup step
//    7. Trial terms clarity in TrialCTAStep
//    8. Progress persistence via UserDefaults
//    9. Skip button on non-critical steps (Features, PowerFeatures)
//

import SwiftUI
import AVFoundation
import AppKit
import Combine
import ServiceManagement

// MARK: - Onboarding Step Enum

enum OnboardingStepID: Int, CaseIterable {
    case welcome = 0
    case microphonePermission
    case microphoneSelection
    case accessibilityPermission
    case shortcutSetup
    case setupPreferences    // NEW: Launch-at-login + Language
    case modelSelection      // CHANGED: Cloud-first model selection
    case features            // Skippable
    case powerFeatures       // Skippable
    case tryItOut
    case trialCTA            // NEW: Clear trial terms
    
    var isSkippable: Bool {
        switch self {
        case .features, .powerFeatures:
            return true
        default:
            return false
        }
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @State private var currentStep: Int = 0
    @State private var isCompleted = false
    let onComplete: () -> Void
    
    // Step-specific state
    @State private var selectedMicrophoneID: String?
    @State private var selectedShortcutKey: UInt32?
    @State private var selectedModel: AIModel?
    @State private var dictatedText: String = ""
    @State private var isDictationComplete = false
    @State private var skippedAccessibility = false
    @State private var launchAtLoginEnabled = true
    @State private var selectedLanguage = "en"
    
    private let steps = OnboardingStepID.allCases
    private var totalSteps: Int { steps.count }
    
    private let persistenceKey = "onboarding_currentStep"
    
    var body: some View {
        ZStack {
            // Dark background with animated particles
            AnimatedBackgroundView()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: index == currentStep ? 20 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStepView(onNext: { goToStep(1) })
                        .tag(0)
                    
                    MicrophonePermissionStepView(
                        onNext: { goToStep(2) },
                        onBack: { goToStep(0) }
                    )
                    .tag(1)
                    
                    MicrophoneSelectionStepView(
                        selectedDeviceID: $selectedMicrophoneID,
                        onNext: { goToStep(3) },
                        onBack: { goToStep(1) }
                    )
                    .tag(2)
                    
                    // Fix #2: Accessibility is soft-required
                    AccessibilityPermissionStepView(
                        onNext: { goToStep(4) },
                        onBack: { goToStep(2) },
                        onSkip: {
                            skippedAccessibility = true
                            UserDefaults.standard.set(true, forKey: "accessibilitySkipped_useClipboard")
                            goToStep(4)
                        }
                    )
                    .tag(3)
                    
                    KeyboardShortcutStepView(
                        selectedKey: $selectedShortcutKey,
                        onNext: { goToStep(5) },
                        onBack: { goToStep(3) }
                    )
                    .tag(4)
                    
                    // Fix #5 & #6: Setup step with Launch-at-Login + Language
                    SetupPreferencesStepView(
                        launchAtLoginEnabled: $launchAtLoginEnabled,
                        selectedLanguage: $selectedLanguage,
                        onNext: { goToStep(6) },
                        onBack: { goToStep(4) }
                    )
                    .tag(5)
                    
                    // Fix #3: Cloud-first model selection
                    CloudFirstModelStepView(
                        selectedModel: $selectedModel,
                        onNext: { goToStep(7) },
                        onBack: { goToStep(5) }
                    )
                    .tag(6)
                    
                    // Fix #9: Skippable Features step
                    FeaturesStepView(
                        onNext: { goToStep(8) },
                        onBack: { goToStep(6) },
                        onSkip: { goToStep(8) }
                    )
                    .tag(7)
                    
                    // Fix #9: Skippable PowerFeatures step
                    PowerFeaturesStepView(
                        onNext: { goToStep(9) },
                        onBack: { goToStep(7) },
                        onSkip: { goToStep(9) }
                    )
                    .tag(8)
                    
                    // Fix #4: Live demo routes to correct engine
                    TryItOutStepView(
                        dictatedText: $dictatedText,
                        isComplete: $isDictationComplete,
                        onComplete: { goToStep(10) },
                        onBack: { goToStep(8) }
                    )
                    .tag(9)
                    
                    // Fix #7: Trial terms clarity
                    TrialCTAStepView(
                        onComplete: complete,
                        onBack: { goToStep(9) }
                    )
                    .tag(10)
                }
                .tabViewStyle(.automatic)
            }
            .frame(width: 700, height: 600)
        }
        .onAppear {
            // Fix #8: Restore progress
            let savedStep = UserDefaults.standard.integer(forKey: persistenceKey)
            if savedStep > 0 && savedStep < totalSteps {
                currentStep = savedStep
            }
        }
    }
    
    // Fix #8: Persist step on navigation
    private func goToStep(_ step: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
        UserDefaults.standard.set(step, forKey: persistenceKey)
    }
    
    private func complete() {
        isCompleted = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        // Fix #1: Start trial AFTER onboarding completes
        LicenseManager.shared.startTrialIfNeeded()
        // Clean up persisted step
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        onComplete()
    }
}

// MARK: - Animated Background View

struct AnimatedBackgroundView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        ZStack {
            Color.black
            
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .animation(.linear(duration: particle.duration).repeatForever(autoreverses: false), value: particle.position)
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<30).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...700),
                    y: CGFloat.random(in: 0...600)
                ),
                size: CGFloat.random(in: 1...3),
                duration: Double.random(in: 3...8)
            )
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let duration: Double
}

// MARK: - Step 1: Welcome

struct WelcomeStepView: View {
    @State private var currentTextIndex = 0
    @State private var displayedText = ""
    @State private var isTyping = false
    
    let onNext: () -> Void
    
    private let texts = [
        "Welcome to the Future of Typing",
        "A New Way to Type",
        "Works Everywhere on Mac with a click"
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                if currentTextIndex == 0 {
                    Text(displayedText)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.1), value: displayedText)
                } else if currentTextIndex == 1 {
                    Text(displayedText)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.1), value: displayedText)
                } else if currentTextIndex == 2 {
                    Text(displayedText)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.1), value: displayedText)
                }
            }
            .frame(height: 120)
            
            Spacer()
            
            Button(action: onNext) {
                HStack {
                    Text("Get Started")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            Button("Skip Tour") {
                onNext()
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
            .font(.caption)
            
            Spacer()
        }
        .onAppear {
            startTextAnimation()
        }
    }
    
    private func startTextAnimation() {
        typeText(at: 0)
    }
    
    private func typeText(at index: Int) {
        guard index < texts.count else { return }
        
        currentTextIndex = index
        displayedText = ""
        let text = texts[index]
        var charIndex = 0
        
        isTyping = true
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if charIndex < text.count {
                displayedText += String(text[text.index(text.startIndex, offsetBy: charIndex)])
                charIndex += 1
            } else {
                timer.invalidate()
                isTyping = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    deleteText(at: index)
                }
            }
        }
    }
    
    private func deleteText(at index: Int) {
        guard !displayedText.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if index + 1 < texts.count {
                    typeText(at: index + 1)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        startTextAnimation()
                    }
                }
            }
            return
        }
        
        displayedText = String(displayedText.dropLast())
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            deleteText(at: index)
        }
    }
}

// MARK: - Step 2: Microphone Permission

struct MicrophonePermissionStepView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @State private var hasRequested = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: permissionsManager.hasMicrophonePermission ? "checkmark.circle.fill" : "mic.fill")
                    .font(.system(size: 60))
                    .foregroundColor(permissionsManager.hasMicrophonePermission ? .green : .blue)
            }
            
            Text("Microphone Access")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Enable your microphone to start speaking and converting your voice to text instantly.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            Spacer()
            
            Button(action: {
                if !permissionsManager.hasMicrophonePermission {
                    hasRequested = true
                    permissionsManager.requestMicrophonePermission { granted in
                        if granted {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onNext()
                            }
                        }
                    }
                } else {
                    onNext()
                }
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            .disabled(hasRequested && !permissionsManager.hasMicrophonePermission)
            
            Spacer()
        }
        .onAppear {
            permissionsManager.checkMicrophonePermission()
        }
        .onChange(of: permissionsManager.hasMicrophonePermission) { oldValue, granted in
            if granted && hasRequested {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onNext()
                }
            }
        }
    }
}

// MARK: - Step 3: Microphone Selection

struct MicrophoneSelectionStepView: View {
    @StateObject private var audioManager = AudioManager.shared
    @Binding var selectedDeviceID: String?
    @State private var availableDevices: [AudioDevice] = []
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            Text("Microphone Selection")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Select the audio input device you want to use with EchoTune.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Microphone:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Picker("Select Microphone", selection: $selectedDeviceID) {
                    ForEach(availableDevices) { device in
                        HStack {
                            if device.isDefault {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            Text(device.name)
                                .foregroundColor(.white)
                        }
                        .tag(device.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                Text("For best results, using your Mac's built-in microphone is recommended.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            Spacer()
        }
        .onAppear {
            loadDevices()
        }
        .onChange(of: selectedDeviceID) { oldValue, newValue in
            if let id = newValue {
                audioManager.selectAudioDevice(id: id)
            }
        }
    }
    
    private func loadDevices() {
        availableDevices = audioManager.getAvailableInputDevices()
        if selectedDeviceID == nil, let defaultDevice = availableDevices.first(where: { $0.isDefault }) {
            selectedDeviceID = defaultDevice.id
        }
    }
}

// MARK: - Step 4: Accessibility Permission (Fix #2: Soft-required with skip)

struct AccessibilityPermissionStepView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @State private var hasRequested = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: permissionsManager.hasAccessibilityPermission ? "checkmark.circle.fill" : "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(permissionsManager.hasAccessibilityPermission ? .green : .blue)
            }
            
            Text("Accessibility Access")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Allow EchoTune to type directly into any app.\nWithout this, text will be copied to your clipboard instead.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            Spacer()
            
            // Main action
            Button(action: {
                if !permissionsManager.hasAccessibilityPermission {
                    hasRequested = true
                    permissionsManager.requestAccessibilityPermission()
                    startPermissionPolling()
                } else {
                    onNext()
                }
            }) {
                Text(permissionsManager.hasAccessibilityPermission ? "Continue" : "Grant Access")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            // Fix #2: Skip option — falls back to clipboard
            if !permissionsManager.hasAccessibilityPermission {
                Button(action: onSkip) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                        Text("Skip — use clipboard instead")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)
                .font(.caption)
            }
            
            Spacer()
        }
        .onAppear {
            permissionsManager.checkAccessibilityPermission()
        }
        .onChange(of: permissionsManager.hasAccessibilityPermission) { oldValue, granted in
            if granted && hasRequested {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onNext()
                }
            }
        }
    }
    
    private func startPermissionPolling() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            permissionsManager.checkAccessibilityPermission()
            if permissionsManager.hasAccessibilityPermission {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Step 5: Keyboard Shortcut

struct KeyboardShortcutStepView: View {
    private let shortcutManager = ShortcutManager.shared
    @Binding var selectedKey: UInt32?
    @State private var selectedKeyString = "F10"
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    private let functionKeys: [(keyCode: UInt32, name: String)] = [
        (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"),
        (96, "F5"), (97, "F6"), (98, "F7"), (100, "F8"),
        (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12")
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            Text("Keyboard Shortcut")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Set up a keyboard shortcut to quickly access EchoTune from anywhere.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Shortcut:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Picker("Select Shortcut", selection: $selectedKeyString) {
                    ForEach(functionKeys, id: \.name) { key in
                        Text(key.name)
                            .tag(key.name)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .onChange(of: selectedKeyString) { newValue in
                    if let key = functionKeys.first(where: { $0.name == newValue }) {
                        selectedKey = key.keyCode
                    }
                }
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            Button(action: {
                if let keyCode = selectedKey ?? functionKeys.first(where: { $0.name == "F10" })?.keyCode {
                    shortcutManager.updateShortcut(keyCode: keyCode, modifiers: 0)
                    shortcutManager.unregisterGlobalShortcut()
                    shortcutManager.registerGlobalShortcut()
                    onNext()
                }
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            Spacer()
        }
        .onAppear {
            selectedKey = functionKeys.first(where: { $0.name == "F10" })?.keyCode
        }
    }
}

// MARK: - Step 6: Setup Preferences (Fix #5 & #6: Launch-at-Login + Language)

struct SetupPreferencesStepView: View {
    @Binding var launchAtLoginEnabled: Bool
    @Binding var selectedLanguage: String
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    private let supportedLanguages: [(code: String, name: String, flag: String)] = [
        ("en", "English", "🇬🇧"),
        ("es", "Español", "🇪🇸"),
        ("fr", "Français", "🇫🇷"),
        ("de", "Deutsch", "🇩🇪"),
        ("ja", "日本語", "🇯🇵"),
        ("zh", "中文", "🇨🇳"),
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            Text("Setup Preferences")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Customize how EchoTune works for you.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            VStack(alignment: .leading, spacing: 20) {
                // Fix #5: Launch at Login
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $launchAtLoginEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch at Login")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Start EchoTune automatically when you log in")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
                
                // Fix #6: Language Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription Language")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Primary language for speech recognition")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text("\(lang.flag) \(lang.name)")
                                .tag(lang.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            Button(action: {
                // Persist preferences
                UserDefaults.standard.set(launchAtLoginEnabled, forKey: "launchAtLogin")
                UserDefaults.standard.set(selectedLanguage, forKey: "transcriptionLanguage")
                
                // Apply launch-at-login
                LaunchAtLoginManager.shared.isEnabled = launchAtLoginEnabled
                
                onNext()
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            Spacer()
        }
    }
}

// MARK: - Step 7: Cloud-First Model Selection (Fix #3)

struct CloudFirstModelStepView: View {
    @StateObject private var modelManager = ModelManager.shared
    @Binding var selectedModel: AIModel?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadComplete = false
    @State private var useCloudTranscription = true
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Transcription Engine")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Choose how EchoTune transcribes your voice.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            // Fix #3: Cloud (Groq) shown as default/recommended
            VStack(spacing: 12) {
                // Cloud option (recommended)
                Button(action: { useCloudTranscription = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("☁️ Cloud Transcription")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("RECOMMENDED")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Text("Powered by Groq • Ready instantly • No download needed")
                                .font(.caption)
                                .foregroundColor(.gray)
                            HStack(spacing: 16) {
                                Label("Fast", systemImage: "bolt.fill")
                                Label("Accurate", systemImage: "checkmark.seal.fill")
                                Label("0 MB", systemImage: "internaldrive")
                            }
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: useCloudTranscription ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(useCloudTranscription ? .blue : .gray)
                            .font(.title2)
                    }
                    .padding()
                    .background(useCloudTranscription ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(useCloudTranscription ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                
                // Local Whisper option (optional)
                Button(action: { useCloudTranscription = false }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("💻 Local Whisper Model")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Runs on-device • Private • Requires download")
                                .font(.caption)
                                .foregroundColor(.gray)
                            if let model = recommendedWhisperModel {
                                HStack(spacing: 16) {
                                    Label(model.formattedSize, systemImage: "arrow.down.circle")
                                    Label("On-device", systemImage: "lock.shield")
                                }
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        Spacer()
                        Image(systemName: useCloudTranscription ? "circle" : "checkmark.circle.fill")
                            .foregroundColor(useCloudTranscription ? .gray : .blue)
                            .font(.title2)
                    }
                    .padding()
                    .background(useCloudTranscription ? Color.gray.opacity(0.1) : Color.blue.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(useCloudTranscription ? Color.clear : Color.blue.opacity(0.5), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 60)
            
            // Download progress for local model
            if !useCloudTranscription && isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 60)
            }
            
            Spacer()
            
            Button(action: {
                if useCloudTranscription {
                    // Set Groq as the active model
                    if let groqModel = modelManager.availableModels.first(where: { $0.id == "groq-whisper-large-v3-turbo" }) {
                        selectedModel = groqModel
                        // Cloud models may not pass isInstalled guard, set directly
                        modelManager.currentModel = groqModel
                        UserDefaults.standard.set(groqModel.id, forKey: "defaultModelID")
                    }
                    onNext()
                } else if let model = recommendedWhisperModel {
                    if model.isInstalled || downloadComplete {
                        selectedModel = model
                        let _ = modelManager.setCurrentModel(model)
                        onNext()
                    } else {
                        downloadModel(model)
                    }
                } else {
                    onNext()
                }
            }) {
                Text(actionButtonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            .disabled(isDownloading)
            
            Spacer()
        }
    }
    
    private var actionButtonText: String {
        if useCloudTranscription { return "Continue" }
        if isDownloading { return "Downloading..." }
        if downloadComplete { return "Continue" }
        if let model = recommendedWhisperModel, model.isInstalled { return "Continue" }
        return "Download & Continue"
    }
    
    private var recommendedWhisperModel: AIModel? {
        modelManager.availableModels.first { $0.id == "base" } ??
        modelManager.availableModels.first { !$0.isBuiltIn && $0.category == .local }
    }
    
    private func downloadModel(_ model: AIModel) {
        isDownloading = true
        downloadProgress = 0
        
        modelManager.downloadModel(model, progressHandler: { progress in
            DispatchQueue.main.async {
                self.downloadProgress = progress
            }
        }) { result in
            DispatchQueue.main.async {
                self.isDownloading = false
                switch result {
                case .success:
                    self.downloadComplete = true
                case .failure:
                    self.downloadComplete = false
                }
            }
        }
    }
}

// MARK: - Step 8: Features (Fix #9: Skippable)

struct FeaturesStepView: View {
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    
    private let features: [(icon: String, title: String, desc: String)] = [
        ("mic.fill", "Voice-to-Text", "Speak naturally and watch your words appear instantly"),
        ("globe", "Works Everywhere", "Type into any app — browsers, editors, messaging"),
        ("keyboard", "One Shortcut", "Press your key, speak, press again — done"),
        ("bolt.fill", "Lightning Fast", "Real-time transcription with cloud or local AI"),
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("What You Can Do")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(features, id: \.title) { feature in
                    VStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        Text(feature.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(feature.desc)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            // Fix #9: Skip button
            Button("Skip") {
                onSkip()
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
            .font(.caption)
            
            Spacer()
        }
    }
}

// MARK: - Step 9: Power Features (Fix #9: Skippable)

struct PowerFeaturesStepView: View {
    let onNext: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    
    private let powerFeatures: [(icon: String, title: String, desc: String)] = [
        ("wand.and.stars", "AI Enhancement", "Auto-correct grammar, punctuation, and formatting"),
        ("text.badge.checkmark", "Smart Prompts", "Transform voice into emails, code, or summaries"),
        ("clock.arrow.circlepath", "History", "Review and reuse past transcriptions"),
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Power Features")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Unlock the full potential of voice typing")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 12) {
                ForEach(powerFeatures, id: \.title) { feature in
                    HStack(spacing: 16) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(feature.desc)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            // Fix #9: Skip button
            Button("Skip") {
                onSkip()
            }
            .buttonStyle(.plain)
            .foregroundColor(.gray)
            .font(.caption)
            
            Spacer()
        }
    }
}

// MARK: - Step 10: Try It Out (Fix #4: Routes to correct engine)

struct TryItOutStepView: View {
    @StateObject private var appCoordinator = AppCoordinator.shared
    @StateObject private var modelManager = ModelManager.shared
    @Binding var dictatedText: String
    @Binding var isComplete: Bool
    @State private var isRecording = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var activeEngine: String = "Cloud (Groq)"
    
    let onComplete: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        HStack(spacing: 40) {
            // Left side - Instructions
            VStack(alignment: .leading, spacing: 24) {
                Text("Try It Out!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Let's test your EchoTune setup.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                
                // Engine indicator (Fix #4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Engine")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(activeEngine)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)
                }
                
                // Shortcut display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Shortcut")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(ShortcutManager.shared.getShortcutString())
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    InstructionStep(number: 1, text: "Click the text area on the right")
                    InstructionStep(number: 2, text: "Press your shortcut key")
                    InstructionStep(number: 3, text: "Speak something")
                    InstructionStep(number: 4, text: "Press your shortcut key again")
                }
                
                Spacer()
                
                if isComplete {
                    Button(action: onComplete) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Button("Skip for now") {
                    onComplete()
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 40)
            
            // Right side - Text area
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $dictatedText)
                        .font(.system(size: 16))
                        .frame(minHeight: 300)
                        .padding(16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                    
                    if dictatedText.isEmpty {
                        Text("Click here and start speaking...")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.leading, 20)
                            .padding(.top, 24)
                            .allowsHitTesting(false)
                    }
                    
                    if isRecording {
                        VStack {
                            HStack {
                                Image(systemName: "record.circle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.large)
                                Text("Recording...")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 40)
        }
        .padding(.vertical, 40)
        .onChange(of: dictatedText) { oldValue, newValue in
            if !newValue.isEmpty {
                isComplete = true
            }
        }
        .onAppear {
            setupDictationListener()
            detectActiveEngine()
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    // Fix #4: Detect and display which engine is active
    private func detectActiveEngine() {
        if let current = modelManager.currentModel {
            if current.category == .cloud {
                activeEngine = "Cloud (Groq)"
            } else if current.isBuiltIn {
                activeEngine = "Apple Speech"
            } else {
                activeEngine = "Local Whisper (\(current.name))"
            }
        } else {
            activeEngine = "Cloud (Groq)"
        }
    }
    
    private func setupDictationListener() {
        appCoordinator.audioManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { isRecording in
                self.isRecording = isRecording
            }
            .store(in: &cancellables)
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(text)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Step 11: Trial CTA (Fix #7: Clear trial terms)

struct TrialCTAStepView: View {
    let onComplete: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            
            Text("You're All Set! 🎉")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("EchoTune is ready to use.")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            
            // Fix #7: Clear trial terms
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Your 7-Day Free Trial")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    trialTermRow(icon: "calendar", text: "Starts now, when you click \"Start Using EchoTune\"")
                    trialTermRow(icon: "calendar.badge.clock", text: "Ends exactly 7 days from now (\(formattedTrialEndDate))")
                    trialTermRow(icon: "infinity", text: "Full access to all features during trial")
                    trialTermRow(icon: "creditcard.trianglebadge.exclamationmark", text: "No credit card required")
                    trialTermRow(icon: "bell", text: "We'll remind you before it expires")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
            .padding(.horizontal, 60)
            
            Spacer()
            
            Button(action: onComplete) {
                HStack {
                    Text("Start Using EchoTune")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
            Spacer()
        }
    }
    
    private var formattedTrialEndDate: String {
        let endDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: endDate)
    }
    
    @ViewBuilder
    private func trialTermRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
