//
//  Note.swift
//  beacon
//
//  Created by AI Assistant on 2025-07-25.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var userId: String // Linking to your Supabase user
    var content: String
    var createdAt: Date
    
    init(content: String = "", userId: String = "") {
        self.id = UUID()
        self.userId = userId
        self.content = content
        self.createdAt = Date()
    }
}
