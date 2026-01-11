import Foundation
import SwiftData

@Model
class Note {
    var id: UUID
    var userId: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(content: String, userId: String = "") {
        self.id = UUID()
        self.userId = userId
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}