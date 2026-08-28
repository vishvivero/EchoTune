//
//  Note.swift
//  EchoTune
//
//  Model for structured note capture
//

import Foundation

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var items: [NoteItem]
    var dateCreated: Date
    var dateModified: Date
    var isFavorite: Bool
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        items: [NoteItem] = [],
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.items = items
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.isFavorite = isFavorite
        self.tags = tags
    }
}

struct NoteItem: Identifiable, Codable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    var type: NoteItemType

    init(id: UUID = UUID(), text: String, isCompleted: Bool = false, type: NoteItemType = .bullet) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.type = type
    }
}

enum NoteItemType: String, Codable {
    case bullet = "bullet"
    case checkbox = "checkbox"
    case numbered = "numbered"
}
