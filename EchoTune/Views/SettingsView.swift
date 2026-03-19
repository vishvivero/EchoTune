//
//  SettingsView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//  Redesigned with macOS Ventura-style sidebar navigation
//  Streamlined from 9 tabs to 6 tabs
//

import SwiftUI

// MARK: - Settings Tab Definition

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case aiModels = "AI Models"
    case aiAutomation = "AI & Automation"
    case hotkeys = "Hotkeys"
    case permissionsPrivacy = "Permissions & Privacy"
    case aboutLicense = "About & License"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .aiModels: return "cpu"
        case .aiAutomation: return "sparkles"
        case .hotkeys: return "keyboard"
        case .permissionsPrivacy: return "lock.shield"
        case .aboutLicense: return "key.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .aiModels: return .blue
        case .aiAutomation: return .purple
        case .hotkeys: return .orange
        case .permissionsPrivacy: return .red
        case .aboutLicense: return .teal
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar navigation
            settingsSidebar

            // Divider
            Divider()

            // Right content area
            settingsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        isSelected: selectedTab == tab
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
        .frame(width: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Content

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading) {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .aiModels:
                    AIModelsSettingsView()
                case .aiAutomation:
                    AIAutomationSettingsView()
                case .hotkeys:
                    HotkeysView()
                case .permissionsPrivacy:
                    PermissionsPrivacySettingsView()
                case .aboutLicense:
                    AboutLicenseSettingsView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Sidebar Row

struct SettingsSidebarRow: View {
    let tab: SettingsTab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : tab.iconColor)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? tab.iconColor : tab.iconColor.opacity(0.15))
                )

            Text(tab.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
