//
//  SettingsView.swift
//  EchoTune
//
//  Created by Vishnu Raj on 25/10/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab = "General"

    let tabs = ["General", "AI & Models", "Settings", "Privacy", "License"]

    var body: some View {
        VStack {
            // Tabs
            HStack {
                ForEach(tabs, id: \.self) { tab in
                    Button(tab) {
                        selectedTab = tab
                    }
                    .buttonStyle(SettingsTabButtonStyle(isSelected: selectedTab == tab))
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Content
            ScrollView {
                VStack(alignment: .leading) {
                    switch selectedTab {
                    case "General":
                        GeneralSettingsView()
                    case "AI & Models":
                        AIAndModelsView()
                    case "Settings":
                        ConsolidatedSettingsView()
                    case "Privacy":
                        PrivacySettingsView()
                    case "License":
                        LicenseSettingsView()
                    default:
                        Text("Settings")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SettingsTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(8)
    }
}

// Consolidated Settings View (combines Hotkeys, Power Modes, and Advanced)
struct ConsolidatedSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Hotkeys Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "keyboard")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Hotkeys")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Divider()

                HotkeysView()
            }

            Divider()
                .padding(.vertical, 8)

            // Power Modes Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Power Modes")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Divider()

                PowerModesView()
            }

            Divider()
                .padding(.vertical, 8)

            // Advanced Settings Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("Advanced Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Divider()

                AdvancedSettingsView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}







