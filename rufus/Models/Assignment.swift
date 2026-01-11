//
//  Assignment.swift
//  rufus
//
//  Created by AI Assistant on 2025-07-25.
//

import Foundation
import SwiftData

@Model
final class Assignment {
    var id: UUID
    var title: String
    var assignmentDescription: String
    var dueDate: Date
    var isCompleted: Bool
    var reminderDate: Date
    var subject: String
    var priority: Priority
    
    var course: Course?
    
    enum Priority: String, CaseIterable, Codable, Comparable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
        
        var intValue: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            case .urgent: return 3
            }
        }
        
        static func < (lhs: Priority, rhs: Priority) -> Bool {
            return lhs.intValue < rhs.intValue
        }
    }
    
    init(
        title: String,
        assignmentDescription: String = "",
        dueDate: Date,
        reminderDate: Date,
        subject: String = "",
        priority: Priority = .medium,
        course: Course? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.assignmentDescription = assignmentDescription
        self.dueDate = dueDate
        self.isCompleted = false
        self.reminderDate = reminderDate
        self.subject = subject
        self.priority = priority
        self.course = course
    }
}
