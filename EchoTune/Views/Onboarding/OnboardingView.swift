//
//  OnboardingView.swift
//  EchoTune
//
//  Comprehensive 7-Step Onboarding Flow
//

import SwiftUI
import AVFoundation
import AppKit
import Combine

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var isCompleted = false
    let onComplete: () -> Void
    
    // Step-specific state
    @State private var selectedMicrophoneID: String?
    @State private var selectedShortcutKey: UInt32?
    @State private var selectedModel: AIModel?
    @State private var dictatedText: String = ""
    @State private var isDictationComplete = false
    
    private let totalSteps = 7
    
    var body: some View {
        ZStack {
            // Dark background with animated particles
            AnimatedBackgroundView()
            
            VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStepView(onNext: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 1
                        }
                    })
                    .tag(0)
                    
                    MicrophonePermissionStepView(
                        onNext: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 2
                            }
                        },
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 0
                            }
                        }
                    )
                    .tag(1)
                    
                    MicrophoneSelectionStepView(
                        selectedDeviceID: $selectedMicrophoneID,
                        onNext: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 3
                            }
                        },
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 1
                            }
                        }
                    )
                    .tag(2)
                    
                    AccessibilityPermissionStepView(
                        onNext: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 4
                            }
                        },
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 2
                            }
                        }
                    )
                    .tag(3)
                    
                    KeyboardShortcutStepView(
                        selectedKey: $selectedShortcutKey,
                        onNext: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 5
                            }
                        },
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 3
                            }
                        }
                    )
                    .tag(4)
                    
                    ModelDownloadStepView(
                        selectedModel: $selectedModel,
                        onNext: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 6
                            }
                        },
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 4
                            }
                        }
                    )
                    .tag(5)
                    
                    TryItOutStepView(
                        dictatedText: $dictatedText,
                        isComplete: $isDictationComplete,
                        onComplete: complete,
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 5
                            }
                        }
                    )
                    .tag(6)
                }
                .tabViewStyle(.automatic)
            }
            .frame(width: 700, height: 600)
        }
    }
    
    private func complete() {
        isCompleted = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
}

// MARK: - Animated Background View

struct AnimatedBackgroundView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        ZStack {
            Color.black
            
            // Animated particles
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
            
            // Animated text
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
            
            // Get Started Button
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
            
            // Skip Tour
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
                
                // Wait then delete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    deleteText(at: index)
                }
            }
        }
    }
    
    private func deleteText(at index: Int) {
        guard !displayedText.isEmpty else {
            // Move to next text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if index + 1 < texts.count {
                    typeText(at: index + 1)
                } else {
                    // All texts done, restart or stay on last
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
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: permissionsManager.hasMicrophonePermission ? "checkmark.circle.fill" : "mic.fill")
                    .font(.system(size: 60))
                    .foregroundColor(permissionsManager.hasMicrophonePermission ? .green : .blue)
            }
            
            // Title
            Text("Microphone Access")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text("Enable your microphone to start speaking and converting your voice to text instantly.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            Spacer()
            
            // Action Button
            Button(action: {
                if !permissionsManager.hasMicrophonePermission {
                    hasRequested = true
                    permissionsManager.requestMicrophonePermission { granted in
                        if granted {
                            // Auto-advance after short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onNext()
                            }
                        }
                    }
                } else {
                    onNext()
                }
            }) {
                Text(permissionsManager.hasMicrophonePermission ? "Continue" : "Continue")
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
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            // Title
            Text("Microphone Selection")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text("Select the audio input device you want to use with EchoTune.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            // Microphone Picker
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
            
            // Action Button
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

// MARK: - Step 4: Accessibility Permission

struct AccessibilityPermissionStepView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @State private var hasRequested = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: permissionsManager.hasAccessibilityPermission ? "checkmark.circle.fill" : "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(permissionsManager.hasAccessibilityPermission ? .green : .blue)
            }
            
            // Title
            Text("Accessibility Access")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text("Allow EchoTune to help you type anywhere in your Mac.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            Spacer()
            
            // Action Button
            Button(action: {
                if !permissionsManager.hasAccessibilityPermission {
                    hasRequested = true
                    permissionsManager.requestAccessibilityPermission()
                    
                    // Poll for permission change
                    startPermissionPolling()
                } else {
                    onNext()
                }
            }) {
                Text(permissionsManager.hasAccessibilityPermission ? "Continue" : "Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
            
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
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            // Title
            Text("Keyboard Shortcut")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text("Set up a keyboard shortcut to quickly access EchoTune from anywhere.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            // Shortcut Selection
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
            
            // Action Button
            Button(action: {
                if let keyCode = selectedKey ?? functionKeys.first(where: { $0.name == "F10" })?.keyCode {
                    // Set shortcut (function keys don't need modifiers)
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
            // Default to F10
            selectedKey = functionKeys.first(where: { $0.name == "F10" })?.keyCode
        }
    }
}

// MARK: - Step 6: Model Download

struct ModelDownloadStepView: View {
    @StateObject private var modelManager = ModelManager.shared
    @Binding var selectedModel: AIModel?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadComplete = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            // Title
            Text("Download AI Model")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            // Description
            Text("We'll download the optimized model to get you started.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            // Model Card
            if let model = recommendedModel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(formatSize(model.size)) • \(model.language)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Speed")
                                .font(.caption)
                                .foregroundColor(.gray)
                            HStack(spacing: 4) {
                                ForEach(0..<5) { index in
                                    Circle()
                                        .fill(index < model.speedRating ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Accuracy")
                                .font(.caption)
                                .foregroundColor(.gray)
                            HStack(spacing: 4) {
                                ForEach(0..<5) { index in
                                    Circle()
                                        .fill(index < model.accuracyRating ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("RAM")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(Int(model.size / 1024 / 1024)) MB")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal, 60)
            }
            
            // Download Progress
            if isDownloading {
                VStack(spacing: 12) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                    
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 60)
            }
            
            Spacer()
            
            // Action Buttons
            if downloadComplete {
                Button(action: onNext) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 60)
            } else if !isDownloading {
                HStack(spacing: 12) {
                    Button("Skip for now") {
                        onNext()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Download Model") {
                        downloadModel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 60)
            }
            
            Spacer()
        }
        .onAppear {
            selectedModel = recommendedModel
        }
    }
    
    private var recommendedModel: AIModel? {
        // Recommend base model as a good balance
        modelManager.availableModels.first { $0.id == "base" } ??
        modelManager.availableModels.first { !$0.isBuiltIn }
    }
    
    private func downloadModel() {
        guard let model = selectedModel, !model.isInstalled else {
            onNext()
            return
        }
        
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
                    // Still allow continue
                    self.downloadComplete = false
                }
            }
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024 / 1024
        return String(format: "%.0f MB", mb)
    }
}

// MARK: - Step 7: Try It Out

struct TryItOutStepView: View {
    @StateObject private var appCoordinator = AppCoordinator.shared
    @Binding var dictatedText: String
    @Binding var isComplete: Bool
    @State private var isRecording = false
    @State private var cancellables = Set<AnyCancellable>()
    
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
                
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    InstructionStep(number: 1, text: "Click the text area on the right")
                    InstructionStep(number: 2, text: "Press your shortcut key")
                    InstructionStep(number: 3, text: "Speak something")
                    InstructionStep(number: 4, text: "Press your shortcut key again")
                }
                
                Spacer()
                
                // Complete button (only shows when text is entered)
                if isComplete {
                    Button(action: onComplete) {
                        Text("Complete Setup")
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
                    
                    // Recording indicator
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
        }
        .onDisappear {
            // Clean up listeners
            cancellables.removeAll()
        }
    }
    
    private func setupDictationListener() {
        // Listen for recording state to show indicator
        appCoordinator.audioManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { isRecording in
                self.isRecording = isRecording
            }
            .store(in: &cancellables)
        
        // Note: For the "Try It Out" step, users can manually type or use the shortcut
        // The dictated text will be updated when they actually use the dictation feature
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

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
