//
//  NotesView.swift
//  EchoTune
//
//  Voice-powered note taking with structured formatting
//

import SwiftUI

// MARK: - Coming Soon View (Active)

struct NotesContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.6))

            VStack(spacing: 12) {
                Text("Notes - Coming Soon")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Voice-powered note taking with structured formatting")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 16) {
                NotesFeatureRow(icon: "mic.fill", title: "Voice Dictation", description: "Create notes using your voice")
                NotesFeatureRow(icon: "list.bullet.clipboard", title: "Smart Lists", description: "Automatic bullet points, todos, and checkboxes")
                NotesFeatureRow(icon: "square.and.pencil", title: "Rich Editing", description: "Edit and organize your notes with ease")
                NotesFeatureRow(icon: "magnifyingglass", title: "Search & Filter", description: "Find notes instantly with powerful search")
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 40)

            Text("We're working hard to bring this feature to you soon!")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct NotesFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}
