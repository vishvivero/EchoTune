//
//  SetupStep.swift
//  EchoTune
//
//  Onboarding Step 3: Setup (Mic + Model + Shortcut)
//

import SwiftUI

struct SetupStep: View {
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
                    subtitle: isRecordingShortcut ? "Press your desired shortcut\u{2026}" : "Press to start/stop dictation"
                ) {
                    if isRecordingShortcut {
                        HStack(spacing: 6) {
                            Text(recordedShortcutDisplay.isEmpty ? "Waiting\u{2026}" : recordedShortcutDisplay)
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
                            Text(modelManager.isReady ? "Verifying\u{2026}" : "Checking\u{2026}")
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
                Text("You can skip \u{2014} Apple Speech will be used instead")
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
        if downloadFailed { return "Model setup failed \u{2014} try again or skip" }
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
                    self.recordedShortcutDisplay = modStr + "\u{2026}"
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
