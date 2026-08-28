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
        HStack(spacing: 8) {
            Image(systemName: tab.iconName)
                .font(.body)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 18)
            Text(tab.rawValue)
                .font(.body)
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
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
    
    @State private var isAdvancedMode = false
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                // Segmented picker for Basic/Advanced
                Picker("", selection: $isAdvancedMode) {
                    Text("Basic").tag(false)
                    Text("Advanced").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(12)
                
                VStack(spacing: 4) {
                    if !isAdvancedMode {
                        ForEach([SettingsTab.general, .hotkeys, .permissions]) { tab in
                            SettingsSidebarRow(tab: tab, isSelected: selectedTab == tab) {
                                selectedTab = tab
                            }
                        }
                    } else {
                        ForEach([SettingsTab.aiModels, .automation, .privacy, .license]) { tab in
                            SettingsSidebarRow(tab: tab, isSelected: selectedTab == tab) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
            }
            .frame(width: 140)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Detail pane
            VStack {
                switch selectedTab {
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
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 465, idealWidth: 465, maxWidth: .infinity, minHeight: 345, idealHeight: 345, maxHeight: .infinity)
        .onChange(of: isAdvancedMode) { _, newValue in
            // Automatically switch selected tab when switching mode
            selectedTab = newValue ? .aiModels : .general
        }
    }
}

struct SettingsContentView: View {
    var body: some View {
        SettingsView()
    }
}

