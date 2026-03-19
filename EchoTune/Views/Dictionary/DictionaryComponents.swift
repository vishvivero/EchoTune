//
//  DictionaryComponents.swift
//  EchoTune
//
//  Reusable small components for the Dictionary views
//

import SwiftUI

// MARK: - Dictionary Stat Card

struct DictionaryStatCard: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 13))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Example Row (for empty states)

struct ExampleRow: View {
    let word: String
    let variations: String

    var body: some View {
        HStack(spacing: 8) {
            Text(word)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            Text("\u{2190}")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(variations)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
