//
//  SettingsView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI
import Combine

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case hotkeys = "Hotkeys"
    case permissions = "Permissions"
    
    case aiModels = "AI & Models"
    case automation = "Automation"
    case privacy = "Privacy"
    case license = "About & License"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .hotkeys: return "keyboard"
        case .permissions: return "lock.shield"
        case .aiModels: return "cpu"
        case .automation: return "bolt.fill"
        case .privacy: return "eye.slash.fill"
        case .license: return "info.circle"
        }
    }
}

struct SettingsSidebarRow: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.iconName)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 20)
            Text(tab.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.75))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var settings: AppSettings

    @State private var selectedTab: SettingsTab = .general

    // Logical grouping for the sidebar (all tabs always visible, no hide-behind-a-mode).
    private static let groups: [(header: String, tabs: [SettingsTab])] = [
        (
            header: "General",
            tabs: [.general, .hotkeys, .permissions]
        ),
        (
            header: "Intelligence",
            tabs: [.aiModels, .automation]
        ),
        (
            header: "App",
            tabs: [.privacy, .license]
        )
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Self.groups, id: \.header) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.header.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            ForEach(group.tabs) { tab in
                                SettingsSidebarRow(tab: tab, isSelected: selectedTab == tab) {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            .frame(width: 190)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Detail pane — roomier
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    headerTitle(for: selectedTab)
                        .padding(.bottom, 16)

                    detailView(for: selectedTab)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 680, idealWidth: 720, maxWidth: .infinity, minHeight: 420, idealHeight: 480, maxHeight: .infinity)
    }

    @ViewBuilder
    private func headerTitle(for tab: SettingsTab) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tab.iconName)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
            Text(tab.rawValue)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private func detailView(for tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            GeneralSettingsView()
        case .hotkeys:
            HotkeySettingsView()
        case .permissions:
            PermissionsPrivacySettingsView()
        case .aiModels:
            AIModelsSettingsView()
        case .automation:
            AIAutomationSettingsView()
        case .privacy:
            PrivacySettingsView()
        case .license:
            AboutLicenseSettingsView()
        }
    }
}

struct SettingsContentView: View {
    var body: some View {
        SettingsView()
    }
}

