//
//  Course.swift
//  rufus
//
//  Created by AI Assistant on 2025-07-28.
//

import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID
    var name: String
    var code: String
    var color: String
    var professor: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Assignment.course)
    var assignments: [Assignment] = []
    
    init(
        name: String,
        code: String = "",
        color: String = "#007AFF",
        professor: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.code = code
        
        self.color = Course.validateColorString(color)
        self.professor = professor
        self.createdAt = Date()
    }
    
    // Helper method to validate hex color strings
    private static func validateColorString(_ colorString: String) -> String {
        let cleanColor = colorString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        // Check if it's a valid hex color (3, 6, or 8 characters)
        if cleanColor.count == 3 || cleanColor.count == 6 || cleanColor.count == 8 {
            // Try to parse as hex
            var int: UInt64 = 0
            if Scanner(string: cleanColor).scanHexInt64(&int) {
                return "#" + cleanColor
            }
        }
        
        // Return default blue if validation fails
        return "#007AFF"
    }
}

// MARK: - Course Extensions
extension Course {
    static let defaultColors = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#AF52DE", // Purple
        "#FF2D92", // Pink
        "#5AC8FA", // Light Blue
        "#FFCC00", // Yellow
        "#FF6B35", // Orange Red
        "#32D74B"  // Light Green
    ]
    
    var displayName: String {
        if code.isEmpty {
            return name
        } else {
            return "\(code) - \(name)"
        }
    }
}
