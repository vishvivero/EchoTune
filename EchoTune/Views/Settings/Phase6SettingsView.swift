//
//  Phase6SettingsView.swift
//  EchoTune
//
//  Phase 6 UI: Main Settings Coordinator
//  Combines all Phase 6 settings in a tabbed interface
//

import SwiftUI

struct Phase6SettingsView: View {
    @State private var selectedTab: SettingsTab = .apiKeys

    enum SettingsTab: String, CaseIterable, Identifiable {
        case apiKeys = "API Keys"
        case hotkeys = "Hotkeys"
        case powerModes = "Power Modes"
        case aiEnhancement = "AI Enhancement"
        case dictionary = "Dictionary"
        case advanced = "Advanced"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .apiKeys: return "key.fill"
            case .hotkeys: return "command"
            case .powerModes: return "bolt.fill"
            case .aiEnhancement: return "sparkles"
            case .dictionary: return "text.book.closed"
            case .advanced: return "gearshape.2"
            }
        }

        var color: Color {
            switch self {
            case .apiKeys: return .orange
            case .hotkeys: return .blue
            case .powerModes: return .purple
            case .aiEnhancement: return .pink
            case .dictionary: return .green
            case .advanced: return .gray
            }
        }
    }

    var body: some View {
        NavigationView {
            // Sidebar
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label {
                    Text(tab.rawValue)
                } icon: {
                    Image(systemName: tab.icon)
                        .foregroundColor(tab.color)
                }
                .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
            .navigationTitle("Settings")

            // Content
            Group {
                switch selectedTab {
                case .apiKeys:
                    APIKeysView()
                case .hotkeys:
                    HotkeysView()
                case .powerModes:
                    PowerModesView()
                case .aiEnhancement:
                    AIEnhancementView()
                case .dictionary:
                    DictionaryManagementView()
                case .advanced:
                    AdvancedSettingsView()
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }
}

// Standalone window version for direct access
struct Phase6SettingsWindow: View {
    var body: some View {
        Phase6SettingsView()
            .frame(minWidth: 900, minHeight: 700)
    }
}

#Preview {
    Phase6SettingsView()
        .frame(width: 1000, height: 800)
}
