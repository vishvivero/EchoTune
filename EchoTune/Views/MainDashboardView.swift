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
    @State private var selectedView: NavigationItem = .home

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selectedView: $selectedView)
                .frame(minWidth: 200, maxWidth: 250)
        } detail: {
            // Main content area
            DetailView(selectedView: $selectedView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

// MARK: - Navigation Items

enum NavigationItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case dictionary = "Dictionary"
    case notes = "Notes"
    case models = "AI Models"
    case permissions = "Permissions"
    case settings = "Settings"
    case share = "Share"
    case helpFeedback = "Help & Feedback"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .dictionary: return "book.fill"
        case .notes: return "note.text"
        case .models: return "cpu"
        case .permissions: return "lock.shield.fill"
        case .settings: return "gearshape.fill"
        case .share: return "square.and.arrow.up.fill"
        case .helpFeedback: return "questionmark.circle"
        }
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

                if let currentModel = appCoordinator.modelManager.currentModel {
                    HStack {
                        Image(systemName: currentModel.isBuiltIn ? "apple.logo" : "cpu")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text(currentModel.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05))
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
                        ForEach(NavigationItem.allCases) { item in
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
            }

            Spacer()

            // Footer
            VStack(spacing: 12) {
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

                VStack(spacing: 4) {
                    Text("Version 1.0.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if !appCoordinator.licenseManager.isLicensed {
                        Text("Trial: \(appCoordinator.licenseManager.trialDaysRemaining) days left")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
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
        - EchoTune Version: 1.0.0

        Permissions:
        - Microphone: \(permissionsManager.hasMicrophonePermission ? "Granted" : "Not Granted")
        - Accessibility: \(permissionsManager.hasAccessibilityPermission ? "Granted" : "Not Granted")

        Current Settings:
        - Default Model: \(modelManager.currentModel?.name ?? "None")
        - Installed Models: \(modelManager.installedModels.map { $0.name }.joined(separator: ", "))
        - Auto Punctuation: \(settings.autoPunctuation ? "On" : "Off")
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
            case .dictionary:
                DictionaryContentView()
            case .notes:
                NotesContentView()
            case .models:
                ModelsContentView()
            case .permissions:
                PermissionsContentView()
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

// MARK: - Home Content

struct HomeContentView: View {
    @Binding var selectedView: NavigationItem
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var historyManager = TranscriptionHistoryManager.shared
    @ObservedObject private var analyticsManager = AnalyticsManager.shared
    @State private var showStatsDialog = false
    @State private var showReferralSheet = false

    private var stats: UsageStatistics {
        analyticsManager.statistics
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Welcome Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back, \(NSFullUserName())")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    // Quick Stats - Clickable
                    Button(action: {
                        showStatsDialog = true
                    }) {
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(calculateDaysUsed()) days")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.green)
                                Text("\(stats.totalTranscriptions)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "text.word.spacing")
                                    .foregroundColor(.blue)
                                Text("\(formatNumber(stats.totalWords))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "gauge.high")
                                    .foregroundColor(.purple)
                                Text("\(calculateAverageWPM()) WPM")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .help("Click to view detailed statistics")
                }
                .padding(.top, 32)

                // Referral Banner (Direct sale only - not allowed in App Store)
                #if !APPSTORE
                ReferralBanner(showReferralSheet: $showReferralSheet)
                #endif

                // Collapsible Shortcut Instruction Banner
                ShortcutInstructionBanner()

                // Time Saved Card - Enhanced
                if stats.totalWords > 0 {
                    // Keep typing WPM constant at 40 (average typing speed)
                    let typingWPM = 40.0

                    // Calculate actual speaking WPM based on user's data
                    // If user has recording time, calculate their actual WPM
                    // Otherwise use average speaking speed of 150 WPM
                    let speakingWPM: Double = {
                        if stats.totalRecordingTime > 0 {
                            let minutes = stats.totalRecordingTime / 60
                            let calculatedWPM = Double(stats.totalWords) / minutes
                            // Clamp between 80-300 WPM to avoid unrealistic values
                            return min(max(calculatedWPM, 80), 300)
                        }
                        return 150.0 // Default average speaking speed
                    }()

                    // Calculate dynamic speed factor
                    let speedFactor = speakingWPM / typingWPM

                    let typingTimeMinutes = Double(stats.totalWords) / typingWPM
                    let recordingTimeMinutes = stats.totalRecordingTime / 60
                    let timeSavedMinutes = typingTimeMinutes - recordingTimeMinutes

                    VStack(alignment: .leading, spacing: 20) {
                        // Main Achievement Card
                        HStack(alignment: .center, spacing: 20) {
                            // Large Icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green, Color.blue]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 70, height: 70)
                                    .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)

                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("You're **\(String(format: "%.1fx", speedFactor))** faster with EchoTune!")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Speaking at **\(Int(speakingWPM)) WPM** vs typing at **\(Int(typingWPM)) WPM**")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 12)

                        // Time Breakdown
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("⏱️ Time Saved")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text(formatDetailedTime(timeSavedMinutes * 60))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.green)
                            }

                            Divider()
                                .frame(height: 40)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("⌨️ Typing Would Take")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text(formatDetailedTime(typingTimeMinutes * 60))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.orange)
                            }

                            Divider()
                                .frame(height: 40)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("🎤 Recording Time")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text(formatDetailedTime(stats.totalRecordingTime))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green.opacity(0.08), Color.blue.opacity(0.08)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                }

                // Usage Graph
                UsageGraphView(stats: stats)

                // Recent Transcriptions Section
                if !historyManager.transcriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Transcriptions")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()

                            Text("\(historyManager.transcriptions.count) total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Group transcriptions by date
                        ForEach(groupedTranscriptions.keys.sorted(by: >), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 12) {
                                // Date header
                                Text(formatDateHeader(date))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.top, 8)

                                // Transcriptions for this date
                                ForEach(groupedTranscriptions[date] ?? []) { item in
                                    CompactTranscriptionRow(item: item, onDelete: {
                                        historyManager.deleteTranscription(item)
                                    })
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showStatsDialog) {
            StatsDetailDialog(stats: stats)
        }
        #if !APPSTORE
        .sheet(isPresented: $showReferralSheet) {
            ReferralView()
        }
        #endif
        #if APPSTORE
        .sheet(isPresented: $appCoordinator.showPurchaseSheet) {
            PurchaseView()
        }
        #endif
    }

    // Group transcriptions by date
    private var groupedTranscriptions: [Date: [TranscriptionHistoryItem]] {
        Dictionary(grouping: historyManager.transcriptions) { item in
            Calendar.current.startOfDay(for: item.date)
        }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%dm %ds", minutes, secs)
    }

    private func formatDetailedTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func calculateTypingTime(words: Int) -> Double {
        // Average typing speed: 40 WPM
        let wordsPerMinute = 40.0
        return Double(words) / wordsPerMinute
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func calculateAverageWPM() -> Int {
        guard stats.totalRecordingTime > 0 else { return 0 }
        let minutes = stats.totalRecordingTime / 60
        return Int(Double(stats.totalWords) / minutes)
    }

    private func calculateDaysUsed() -> Int {
        let calendar = Calendar.current
        let startDate = appCoordinator.appState.trialStartDate
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return max(1, (components.day ?? 0) + 1) // At least 1 day
    }
}

// MARK: - Compact Transcription Row

struct CompactTranscriptionRow: View {
    let item: TranscriptionHistoryItem
    let onDelete: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    // Text content
                    Text(item.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(isHovering ? nil : 3)
                        .animation(.easeInOut, value: isHovering)

                    // Time and word count
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatTime(item.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "text.word.spacing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(item.wordCount) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDuration(item.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Actions on hover
                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: { copyToClipboard() }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")

                        if let onDelete = onDelete {
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.body)
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
    }
}

// MARK: - Dashboard Stat Card

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Recording Toggle Button

struct RecordingToggleButton: View {
    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        let isRecording = appCoordinator.appState.recordingState == .recording
        let isProcessing = appCoordinator.appState.recordingState == .processing

        Button(action: {
            if isRecording {
                appCoordinator.stopDictation()
            } else if !isProcessing {
                appCoordinator.startDictation()
            }
        }) {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title3)
                }

                Text(isProcessing ? "Processing..." : (isRecording ? "Stop & Transcribe" : "Start Recording"))
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isProcessing ? Color.gray : (isRecording ? Color.red : Color.blue))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder Content Views

struct ModelsContentView: View {
    var body: some View {
        AIModelsView()
    }
}

struct SettingsContentView: View {
    var body: some View {
        SettingsView()
            .padding()
    }
}

struct AboutContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("EchoTune")
                .font(.system(size: 36, weight: .bold))

            Text("Version 1.0.0")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("AI-powered voice dictation for Mac")
                .font(.body)
                .foregroundColor(.secondary)

            Text("100% private, all processing on your device")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Divider()
                .padding(.vertical)

            Text("© 2025 EchoTune")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: 600)
    }
}

// Dictionary view is in DictionaryView.swift

// Notes view is in NotesView.swift
// MARK: - Usage Graph View

struct UsageGraphView: View {
    let stats: UsageStatistics
    @State private var selectedPeriod: TimePeriod = .oneMonth

    enum TimePeriod: String, CaseIterable {
        case oneDay = "1D"
        case fiveDays = "5D"
        case twoWeeks = "2W"
        case oneMonth = "1M"

        var days: Int {
            switch self {
            case .oneDay: return 1
            case .fiveDays: return 5
            case .twoWeeks: return 14
            case .oneMonth: return 30
            }
        }
    }

    // Get daily data for the selected period
    private var dailyData: [(date: String, wordCount: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [(String, Int)] = []

        // Go backwards from today for the selected number of days
        for dayOffset in (0..<selectedPeriod.days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dateString = dateFormatter.string(from: date)
                let wordCount = stats.dailyStats[dateString]?.wordCount ?? 0
                data.append((dateString, wordCount))
            }
        }

        return data
    }

    // Get the maximum word count for scaling
    private var maxWordCount: Int {
        let max = dailyData.map { $0.wordCount }.max() ?? 1
        return max > 0 ? max : 100 // Minimum scale of 100 for empty data
    }

    // Calculate actual days with data
    private var daysWithData: Int {
        dailyData.filter { $0.wordCount > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Usage Over Time")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Time period selector
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Button(action: {
                            selectedPeriod = period
                        }) {
                            Text(period.rawValue)
                                .font(.caption)
                                .fontWeight(selectedPeriod == period ? .semibold : .regular)
                                .foregroundColor(selectedPeriod == period ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedPeriod == period ? Color.blue : Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Graph area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 200)

                if dailyData.isEmpty || dailyData.allSatisfy({ $0.wordCount == 0 }) {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No data yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Start using EchoTune to see your usage statistics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        // Simple bar chart visualization
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array(dailyData.enumerated()), id: \.offset) { index, dayData in
                                VStack(spacing: 4) {
                                    let wordCount = dayData.wordCount
                                    let barHeight = wordCount > 0 ?
                                        max(20, CGFloat(wordCount) / CGFloat(maxWordCount) * 140) : 10

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            wordCount > 0 ?
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.6)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ) :
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(height: barHeight)

                                    // Show day labels based on period
                                    if selectedPeriod.days <= 7 {
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else if index % max(1, selectedPeriod.days / 5) == 0 {
                                        Text("\(index + 1)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        Text("Words transcribed per day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Stats summary below graph
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(formatNumber(stats.totalWords))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg per Day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let avgPerDay = daysWithData > 0 ? stats.totalWords / daysWithData : 0
                    Text("\(formatNumber(avgPerDay))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Stats Detail Dialog

struct StatsDetailDialog: View {
    let stats: UsageStatistics
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header with close button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Stats")
                            .font(.system(size: 32, weight: .bold))

                        Text("Keep up the great work!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }

                // Streak Card - Prominent
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.red]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            VStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)

                                Text("\(calculateDaysUsed())")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Day Streak")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("You've been using EchoTune for \(calculateDaysUsed()) \(calculateDaysUsed() == 1 ? "day" : "days")!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                }

                // Key Stats - 2x3 Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatDetailCardEnhanced(
                        title: "Transcriptions",
                        value: "\(stats.totalTranscriptions)",
                        icon: "doc.text.fill",
                        color: .blue,
                        trend: "+\(stats.totalTranscriptions)"
                    )

                    StatDetailCardEnhanced(
                        title: "Words",
                        value: formatNumber(stats.totalWords),
                        icon: "text.alignleft",
                        color: .green,
                        trend: "Total"
                    )

                    StatDetailCardEnhanced(
                        title: "Recording Time",
                        value: formatTime(stats.totalRecordingTime),
                        icon: "clock.fill",
                        color: .orange,
                        trend: "Active"
                    )

                    StatDetailCardEnhanced(
                        title: "Speaking Speed",
                        value: "\(calculateSpeakingWPM()) WPM",
                        icon: "gauge.high",
                        color: .purple,
                        trend: "Average"
                    )

                    StatDetailCardEnhanced(
                        title: "Time Saved",
                        value: formatTime(calculateTimeSaved()),
                        icon: "bolt.fill",
                        color: .yellow,
                        trend: "vs. typing"
                    )

                    StatDetailCardEnhanced(
                        title: "Efficiency",
                        value: String(format: "%.1fx", calculateSpeedFactor()),
                        icon: "arrow.up.circle.fill",
                        color: .pink,
                        trend: "Faster"
                    )
                }

                Spacer(minLength: 20)
            }
            .padding(32)
        }
        .frame(width: 650, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
    
    private func calculateSpeakingWPM() -> Int {
        guard stats.totalRecordingTime > 0 else { return 150 } // Default to 150 WPM
        let minutes = stats.totalRecordingTime / 60
        let calculatedWPM = Double(stats.totalWords) / minutes
        // Clamp between 80-300 WPM to avoid unrealistic values
        return Int(min(max(calculatedWPM, 80), 300))
    }

    private func calculateDaysUsed() -> Int {
        let calendar = Calendar.current
        let startDate = AppState.shared.trialStartDate
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return max(1, (components.day ?? 0) + 1)
    }

    private func calculateTypingTime(words: Int) -> Double {
        let typingWPM = 40.0 // Average typing speed
        return Double(words) / typingWPM
    }

    private func calculateTimeSaved() -> TimeInterval {
        let typingTimeMinutes = calculateTypingTime(words: stats.totalWords)
        let recordingTimeMinutes = stats.totalRecordingTime / 60
        let timeSavedMinutes = typingTimeMinutes - recordingTimeMinutes
        return timeSavedMinutes * 60
    }

    private func calculateSpeedFactor() -> Double {
        let typingWPM = 40.0 // Average typing speed

        // Calculate actual speaking WPM based on user's data
        let speakingWPM: Double = {
            if stats.totalRecordingTime > 0 {
                let minutes = stats.totalRecordingTime / 60
                let calculatedWPM = Double(stats.totalWords) / minutes
                // Clamp between 80-300 WPM to avoid unrealistic values
                return min(max(calculatedWPM, 80), 300)
            }
            return 150.0 // Default average speaking speed
        }()

        return speakingWPM / typingWPM
    }
}

// MARK: - Stat Detail Card

struct StatDetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Stat Detail Card

struct StatDetailCardEnhanced: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                Text(trend)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Shortcut Instruction Banner (Collapsible)

struct ShortcutInstructionBanner: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var isExpanded = false
    @State private var testText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hold down **\(appCoordinator.shortcutManager.getCurrentShortcutString())** to dictate")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Test your microphone and keyboard shortcut")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.blue)
                            Text("Click in the text area below")
                                .font(.subheadline)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.blue)
                            Text("Hold down \(appCoordinator.shortcutManager.getCurrentShortcutString()) and speak")
                                .font(.subheadline)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.blue)
                            Text("Release the key to see your transcription")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Test text area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Try it here:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            if !testText.isEmpty {
                                Button(action: {
                                    testText = ""
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("Clear")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        TextEditor(text: $testText)
                            .font(.body)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )

                        if testText.isEmpty {
                            Text("Click here and hold \(appCoordinator.shortcutManager.getCurrentShortcutString()) to start dictating...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    // Tip
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Tip: This works in any app - email, messages, docs, code editors, and more!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Referral Banner

struct ReferralBanner: View {
    @Binding var showReferralSheet: Bool
    @EnvironmentObject var appCoordinator: AppCoordinator

    private var isProUser: Bool {
        appCoordinator.licenseManager.isLicensed
    }

    private var bannerTitle: String {
        isProUser ? "Share EchoTune, earn rewards" : "Give a month, get a month"
    }

    private var bannerSubtitle: String {
        isProUser ? "Earn $5 for every friend who subscribes!" : "Invite friends and you both get a free month!"
    }

    private var bannerIcon: String {
        isProUser ? "dollarsign.circle.fill" : "gift.fill"
    }

    var body: some View {
        Button(action: {
            showReferralSheet = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: bannerIcon)
                    .font(.title3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(bannerSubtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Share Now")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isProUser ? [
                        Color(red: 0.2, green: 0.7, blue: 0.4),
                        Color(red: 0.15, green: 0.6, blue: 0.35)
                    ] : [
                        Color(red: 0.4, green: 0.6, blue: 1.0),
                        Color(red: 0.3, green: 0.5, blue: 0.9)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: (isProUser ? Color.green : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - License/Subscription Button

struct LicenseSubscriptionButton: View {
    @EnvironmentObject var appCoordinator: AppCoordinator

    private var isPro: Bool {
        appCoordinator.licenseManager.isPro
    }

    private var buttonTitle: String {
        if isPro {
            return "Pro Version"
        } else if !appCoordinator.licenseManager.isTrialExpired {
            return "Trial Active"
        } else {
            #if APPSTORE
            return "Upgrade to Pro"
            #else
            return "Activate License"
            #endif
        }
    }

    private var buttonIcon: String {
        if isPro {
            return "crown.fill"
        } else if !appCoordinator.licenseManager.isTrialExpired {
            return "clock.fill"
        } else {
            return "key.fill"
        }
    }

    private var buttonColor: Color {
        if isPro {
            return .purple
        } else if !appCoordinator.licenseManager.isTrialExpired {
            return .blue
        } else {
            return .orange
        }
    }

    var body: some View {
        Button(action: {
            #if APPSTORE
                // App Store: Show purchase view if not pro
                if isPro {
                    // Just show info, maybe do nothing or show a "You're Pro!" message
                } else {
                    appCoordinator.showPurchaseSheet = true
                }
            #else
                // Direct sale: Show license key entry
                appCoordinator.showLicenseSheet = true
            #endif
        }) {
            HStack(spacing: 8) {
                Image(systemName: buttonIcon)
                    .foregroundColor(buttonColor)
                
                Text(buttonTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !appCoordinator.licenseManager.isLicensed && !appCoordinator.licenseManager.isTrialExpired {
                    Text("\(appCoordinator.licenseManager.trialDaysRemaining)d")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(buttonColor.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $appCoordinator.showLicenseSheet) {
            LicenseSettingsView()
                .frame(width: 600, height: 700)
        }
    }
}

// MARK: - Help & Feedback View

struct HelpFeedbackView: View {
    @State private var showEmailSent = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help & Feedback")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Get support or share your feedback with us")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Quick Help Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Help")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HelpCard(
                        icon: "mic.circle.fill",
                        title: "How to use voice dictation",
                        description: "Press the global shortcut (⌘⇧Space by default) or click 'Quick Record' to start dictating. Speak clearly and the text will be automatically typed.",
                        color: .blue
                    )
                    
                    HelpCard(
                        icon: "cpu",
                        title: "Choosing the right model",
                        description: "Visit AI Models page to see recommended models for your Mac. Smaller models are faster, larger models are more accurate.",
                        color: .green
                    )
                    
                    HelpCard(
                        icon: "keyboard",
                        title: "Customizing shortcuts",
                        description: "Go to Settings to customize keyboard shortcuts, transcription behavior, and other preferences.",
                        color: .orange
                    )
                }
                
                Divider()
                
                // Contact Support Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contact Support")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Have a question or issue? Send us an email and we'll get back to you as soon as possible.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: openFeedbackEmail) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Feedback Email")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    if showEmailSent {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Email client opened!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                    }
                }
                
                Divider()
                
                // Resources Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Resources")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ResourceLink(
                        icon: "book.fill",
                        title: "Documentation",
                        url: "https://echotune.app/docs"
                    )
                    
                    ResourceLink(
                        icon: "questionmark.circle.fill",
                        title: "FAQ",
                        url: "https://echotune.app/faq"
                    )
                    
                    ResourceLink(
                        icon: "video.fill",
                        title: "Video Tutorials",
                        url: "https://echotune.app/tutorials"
                    )
                }
            }
            .padding(32)
        }
        .background(Color(NSColor.windowBackgroundColor))
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
        - macOS: \(systemSpecs.macOSVersion)
        - Processor: \(systemSpecs.processorName)
        - RAM: \(String(format: "%.1f", systemSpecs.totalRAMInGB)) GB
        - Architecture: \(systemSpecs.isAppleSilicon ? "Apple Silicon" : "Intel")
        
        Permissions:
        - Microphone: \(permissionsManager.hasMicrophonePermission ? "✓" : "✗")
        - Accessibility: \(permissionsManager.hasAccessibilityPermission ? "✓" : "✗")
        
        Current Model: \(modelManager.currentModel?.name ?? "None")
        Installed Models: \(modelManager.installedModels.count)
        
        Settings:
        - Launch at startup: \(settings.launchAtStartup ? "On" : "Off")
        - Sound effects: \(settings.playSoundOnStartStop ? "On" : "Off")
        - Auto punctuation: \(settings.autoPunctuation ? "On" : "Off")
        """

        let subject = "EchoTune Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let mailtoString = "mailto:hi@echotune.app?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailtoString) {
            NSWorkspace.shared.open(url)
            showEmailSent = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showEmailSent = false
            }
        }
    }
}

// MARK: - Help Card

struct HelpCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Resource Link

struct ResourceLink: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
