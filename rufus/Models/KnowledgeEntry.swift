//
//  KnowledgeEntry.swift
//  rufus
//
//  Created for private knowledge base feature
//

import Foundation
import SwiftData

@Model
final class KnowledgeEntry {
    var id: UUID
    var title: String
    var content: String  // Markdown-formatted content
    var category: String
    var tags: [String]
    var createdDate: Date
    var updatedDate: Date
    var courseId: UUID?  // Optional link to a course
    var isPrivate: Bool  // Privacy flag
    var isFavorite: Bool  // Star favorite entries

    @Relationship(deleteRule: .cascade)
    var annotations: [KnowledgeAnnotation] = []

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: String = "General",
        tags: [String] = [],
        courseId: UUID? = nil,
        isPrivate: Bool = true,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.createdDate = Date()
        self.updatedDate = Date()
        self.courseId = courseId
        self.isPrivate = isPrivate
        self.isFavorite = isFavorite
    }
}

@Model
final class KnowledgeAnnotation {
    var id: UUID
    var note: String
    var timestamp: Date

    init(id: UUID = UUID(), note: String) {
        self.id = id
        self.note = note
        self.timestamp = Date()
    }
}

// Predefined categories
extension KnowledgeEntry {
    static let categories = [
        "General",
        "Study Notes",
        "Resources",
        "Ideas",
        "Personal",
        "Research",
        "Quick Notes"
    ]
}
