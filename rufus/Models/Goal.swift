//
//  Goal.swift
//  rufus
//
//  Created for personal goals and tasks feature
//

import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var goalDescription: String
    var deadline: Date?
    var priority: Priority
    var category: GoalCategory
    var status: GoalStatus
    var progress: Double  // 0.0 to 1.0
    var createdDate: Date
    var updatedDate: Date
    var isPrivate: Bool  // Privacy control
    var color: String  // Hex color for visual customization
    var icon: String  // SF Symbol name

    @Relationship(deleteRule: .cascade, inverse: \GoalTask.goal)
    var tasks: [GoalTask] = []

    init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String = "",
        deadline: Date? = nil,
        priority: Priority = .medium,
        category: GoalCategory = .personal,
        status: GoalStatus = .notStarted,
        progress: Double = 0.0,
        isPrivate: Bool = true,
        color: String = "#8B5CF6",  // Purple
        icon: String = "target"
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.deadline = deadline
        self.priority = priority
        self.category = category
        self.status = status
        self.progress = progress
        self.createdDate = Date()
        self.updatedDate = Date()
        self.isPrivate = isPrivate
        self.color = color
        self.icon = icon
    }

    // Calculate progress based on completed tasks
    func updateProgress() {
        guard !tasks.isEmpty else {
            progress = 0.0
            return
        }
        let completedCount = tasks.filter { $0.completed }.count
        progress = Double(completedCount) / Double(tasks.count)

        // Auto-update status based on progress
        if progress >= 1.0 {
            status = .completed
        } else if progress > 0.0 {
            status = .inProgress
        }

        updatedDate = Date()
    }
}

@Model
final class GoalTask {
    var id: UUID
    var title: String
    var taskDescription: String
    var dueDate: Date?
    var completed: Bool
    var order: Int  // For ordering within a goal
    var createdDate: Date

    var goal: Goal?

    init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String = "",
        dueDate: Date? = nil,
        completed: Bool = false,
        order: Int = 0,
        goal: Goal? = nil
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.completed = completed
        self.order = order
        self.createdDate = Date()
        self.goal = goal
    }
}

// Enums for Goal
enum GoalCategory: String, CaseIterable, Codable {
    case academic = "Academic"
    case personal = "Personal"
    case health = "Health"
    case career = "Career"
    case financial = "Financial"
    case social = "Social"
    case creative = "Creative"
    case other = "Other"

    var icon: String {
        switch self {
        case .academic: return "graduationcap.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .career: return "briefcase.fill"
        case .financial: return "dollarsign.circle.fill"
        case .social: return "person.2.fill"
        case .creative: return "paintbrush.fill"
        case .other: return "star.fill"
        }
    }

    var color: String {
        switch self {
        case .academic: return "#3B82F6"  // Blue
        case .personal: return "#8B5CF6"  // Purple
        case .health: return "#EF4444"    // Red
        case .career: return "#F59E0B"    // Orange
        case .financial: return "#10B981" // Green
        case .social: return "#EC4899"    // Pink
        case .creative: return "#F97316"  // Orange
        case .other: return "#6B7280"     // Gray
        }
    }
}

enum GoalStatus: String, CaseIterable, Codable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case onHold = "On Hold"

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        }
    }
}

enum Priority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var icon: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .critical: return "exclamationmark.circle"
        }
    }

    var color: String {
        switch self {
        case .low: return "#10B981"      // Green
        case .medium: return "#F59E0B"   // Orange
        case .high: return "#EF4444"     // Red
        case .critical: return "#DC2626" // Dark Red
        }
    }
}
