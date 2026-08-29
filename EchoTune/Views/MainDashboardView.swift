//
//  MainDashboardView.swift
//  EchoTune
//
//  Main Dashboard with Sidebar Navigation
//

import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var appSettings: AppSettings
    @ObservedObject var whisperEngine = WhisperEngine.shared
    @State private var selectedView: NavigationItem = .home

    var body: some View {
        ZStack {
            // Keep navigation and content directly adjacent. NavigationSplitView
            // adds a platform-controlled gutter that makes the dashboard look
            // disconnected at compact widths.
            HStack(spacing: 0) {
                SidebarView(selectedView: $selectedView)
                    .frame(width: 240)

                Divider()

                DetailView(selectedView: $selectedView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #if APPSTORE
            .sheet(isPresented: $appCoordinator.showPurchaseSheet) {
                PurchaseView()
            }
            #endif
            .sheet(isPresented: $appCoordinator.showLicenseSheet) {
                LicenseSettingsView()
                    .frame(width: 600, height: 700)
            }

            // Model Loading Overlay
            if whisperEngine.isLoading {
                VStack {
                    Spacer()
                    ModelLoadingToast(
                        progress: whisperEngine.loadingProgress,
                        stage: whisperEngine.loadingStage
                    )
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: whisperEngine.isLoading)
            }
        }
    }
}

// MARK: - Model Loading Toast

struct ModelLoadingToast: View {
    let progress: Double
    let stage: String

    var body: some View {
        HStack(spacing: 12) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Loading Model")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(stage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .frame(maxWidth: 350)
    }
}

// MARK: - Navigation Items

enum NavigationItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"
    case dictionary = "Dictionary"
    case notes = "Notes"
    case settings = "Settings"
    case share = "Share"
    case helpFeedback = "Help"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .history: return "clock.arrow.circlepath"
        case .dictionary: return "book.fill"
        case .notes: return "note.text"
        case .settings: return "gearshape.fill"
        case .share: return "square.and.arrow.up.fill"
        case .helpFeedback: return "questionmark.circle"
        }
    }

    /// Items to show in sidebar
    static var sidebarItems: [NavigationItem] {
        [
            .home,
            .history, .dictionary, .notes, .settings, .share, .helpFeedback
        ]
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedView: NavigationItem
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var hoveredItem: NavigationItem?

    var body: some View {
        VStack(spacing: 0) {
            // App Header with app icon
            VStack(spacing: 12) {
                // Use the actual app icon
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    // Fallback to gradient circle if icon not found
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)

                        Image(systemName: "waveform")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                VStack(spacing: 4) {
                    Text("EchoTune")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("AI Voice Dictation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)

            // Quick Status Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text("Ready to transcribe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    if let currentModel = appCoordinator.modelManager.currentModel {
                        Image(systemName: currentModel.isBuiltIn ? "apple.logo" : "cpu")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text(currentModel.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "apple.logo")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text("Apple Speech")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Navigation Section
            VStack(alignment: .leading, spacing: 4) {
                Text("NAVIGATION")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(NavigationItem.sidebarItems) { item in
                            ModernSidebarItem(
                                item: item,
                                isSelected: selectedView == item,
                                isHovered: hoveredItem == item,
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedView = item
                                    }
                                }
                            )
                            .onHover { hovering in
                                hoveredItem = hovering ? item : nil
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: .infinity)
            }

            Spacer()

            // Footer
            VStack(alignment: .leading, spacing: 12) {
                Divider()

                // Quick Record Button
                Button(action: {
                    appCoordinator.toggleDictation()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: appCoordinator.appState.recordingState == .recording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.body)

                        Text(appCoordinator.appState.recordingState == .recording ? "Stop" : "Quick Record")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(appCoordinator.appState.recordingState == .recording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // License/Subscription Button
                LicenseSubscriptionButton()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Version \(Bundle.main.appVersionString)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if !appCoordinator.licenseManager.isLicensed {
                        Text("Trial: \(appCoordinator.licenseManager.trialDaysRemaining) days left")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func openFeedbackEmail() {
        // Gather system information
        let systemSpecs = SystemSpecsAnalyzer.shared.getSystemSpecs()
        let permissionsManager = PermissionsManager.shared
        let modelManager = ModelManager.shared
        let settings = AppSettings.shared

        let body = """
        [Please describe your issue or feedback above this line]

        ---
        System Information (auto-generated):

        Hardware:
        - Processor: \(systemSpecs.processorName)
        - Cores: \(systemSpecs.processorCount)
        - RAM: \(String(format: "%.1f", systemSpecs.totalRAMInGB)) GB
        - Architecture: \(systemSpecs.isAppleSilicon ? "Apple Silicon" : "Intel")

        Software:
        - macOS: \(systemSpecs.macOSVersion)
        - EchoTune Version: \(Bundle.main.appVersionString)

        Permissions:
        - Microphone: \(permissionsManager.hasMicrophonePermission ? "Granted" : "Not Granted")
        - Accessibility: \(permissionsManager.hasAccessibilityPermission ? "Granted" : "Not Granted")

        Current Settings:
        - Default Model: \(modelManager.currentModel?.name ?? "None")
        - Installed Models: \(modelManager.installedModels.map { $0.name }.joined(separator: ", "))
        - Smart Capitalization: \(settings.smartCapitalization ? "On" : "Off")
        - Insert Space After Text: \(settings.insertSpaceAfterText ? "On" : "Off")
        """

        // URL encode the body
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Create mailto URL
        let mailtoString = "mailto:hi@echotune.app?subject=EchoTune%20Feedback&body=\(encodedBody)"

        if let mailtoURL = URL(string: mailtoString) {
            NSWorkspace.shared.open(mailtoURL)
        }
    }
}

// MARK: - Modern Sidebar Item

struct ModernSidebarItem: View {
    let item: NavigationItem
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon with background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
                        .frame(width: 32, height: 32)

                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
                }

                Text(item.rawValue)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                // Active indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 3, height: 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail View

struct DetailView: View {
    @Binding var selectedView: NavigationItem

    var body: some View {
        Group {
            switch selectedView {
            case .home:
                HomeContentView(selectedView: $selectedView)
            case .history:
                HistoryView()
            case .dictionary:
                DictionaryContentView()
            case .notes:
                NotesContentView()
            case .settings:
                SettingsContentView()
            case .share:
                ShareStatsView()
            case .helpFeedback:
                HelpFeedbackView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
