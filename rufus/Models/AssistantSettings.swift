//
//  AssistantSettings.swift
//  rufus
//
//  Created for customizable personal assistant feature
//

import Foundation
import SwiftData

@Model
final class AssistantSettings {
    var id: UUID
    var userId: String  // Link to authenticated user

    // Personality customization
    var assistantName: String
    var communicationStyle: CommunicationStyle
    var focusAreas: [String]

    // LLM Configuration
    var responseLength: ResponseLength
    var customSystemPrompt: String?

    // Notification preferences
    var reminderFrequency: ReminderFrequency
    var quietHoursEnabled: Bool
    var quietHoursStart: Date?
    var quietHoursEnd: Date?

    // Learning preferences
    var preferredSubjects: [String]
    var learningStyle: LearningStyle

    // Visual customization
    var themeColor: String  // Hex color
    var assistantEmoji: String

    var createdDate: Date
    var updatedDate: Date

    init(
        id: UUID = UUID(),
        userId: String = "",
        assistantName: String = "Rufus",
        communicationStyle: CommunicationStyle = .casual,
        focusAreas: [String] = ["study", "productivity"],
        responseLength: ResponseLength = .normal,
        customSystemPrompt: String? = nil,
        reminderFrequency: ReminderFrequency = .moderate,
        quietHoursEnabled: Bool = false,
        preferredSubjects: [String] = [],
        learningStyle: LearningStyle = .balanced,
        themeColor: String = "#8B5CF6",
        assistantEmoji: String = "🦊"
    ) {
        self.id = id
        self.userId = userId
        self.assistantName = assistantName
        self.communicationStyle = communicationStyle
        self.focusAreas = focusAreas
        self.responseLength = responseLength
        self.customSystemPrompt = customSystemPrompt
        self.reminderFrequency = reminderFrequency
        self.quietHoursEnabled = quietHoursEnabled
        self.preferredSubjects = preferredSubjects
        self.learningStyle = learningStyle
        self.themeColor = themeColor
        self.assistantEmoji = assistantEmoji
        self.createdDate = Date()
        self.updatedDate = Date()
    }

    // Generate custom system prompt based on settings
    func generateSystemPrompt() -> String {
        var prompt = "You are \(assistantName), a helpful personal assistant. "

        switch communicationStyle {
        case .formal:
            prompt += "Communicate in a professional and formal manner. Use proper grammar and avoid casual language. "
        case .casual:
            prompt += "Communicate in a friendly and casual manner. Be conversational and approachable. "
        case .motivational:
            prompt += "Communicate in an encouraging and motivational manner. Inspire and support the user in achieving their goals. "
        case .concise:
            prompt += "Communicate in a brief and to-the-point manner. Keep responses short and focused. "
        }

        switch responseLength {
        case .brief:
            prompt += "Keep your responses brief and concise, usually 1-2 sentences. "
        case .normal:
            prompt += "Provide balanced responses with sufficient detail. "
        case .detailed:
            prompt += "Provide comprehensive and detailed responses with examples when helpful. "
        }

        switch learningStyle {
        case .visual:
            prompt += "When explaining concepts, emphasize visual descriptions and suggest diagrams or charts. "
        case .auditory:
            prompt += "When explaining concepts, use verbal descriptions and suggest discussing topics aloud. "
        case .readingWriting:
            prompt += "When explaining concepts, provide written explanations and suggest note-taking. "
        case .kinesthetic:
            prompt += "When explaining concepts, suggest hands-on practice and real-world applications. "
        case .balanced:
            prompt += "Use a mix of explanatory approaches. "
        }

        if !focusAreas.isEmpty {
            prompt += "Focus areas: \(focusAreas.joined(separator: ", ")). "
        }

        if !preferredSubjects.isEmpty {
            prompt += "Preferred subjects: \(preferredSubjects.joined(separator: ", ")). "
        }

        if let custom = customSystemPrompt, !custom.isEmpty {
            prompt += custom
        }

        return prompt
    }
}

enum CommunicationStyle: String, CaseIterable, Codable {
    case formal = "Formal"
    case casual = "Casual"
    case motivational = "Motivational"
    case concise = "Concise"

    var description: String {
        switch self {
        case .formal:
            return "Professional and structured"
        case .casual:
            return "Friendly and conversational"
        case .motivational:
            return "Encouraging and supportive"
        case .concise:
            return "Brief and to-the-point"
        }
    }

    var emoji: String {
        switch self {
        case .formal: return "👔"
        case .casual: return "😊"
        case .motivational: return "💪"
        case .concise: return "⚡"
        }
    }
}

enum ResponseLength: String, CaseIterable, Codable {
    case brief = "Brief"
    case normal = "Normal"
    case detailed = "Detailed"

    var description: String {
        switch self {
        case .brief:
            return "Short, quick responses"
        case .normal:
            return "Balanced detail"
        case .detailed:
            return "Comprehensive explanations"
        }
    }
}

enum ReminderFrequency: String, CaseIterable, Codable {
    case minimal = "Minimal"
    case moderate = "Moderate"
    case frequent = "Frequent"

    var description: String {
        switch self {
        case .minimal:
            return "Only critical reminders"
        case .moderate:
            return "Important tasks & deadlines"
        case .frequent:
            return "All tasks & suggestions"
        }
    }
}

enum LearningStyle: String, CaseIterable, Codable {
    case visual = "Visual"
    case auditory = "Auditory"
    case readingWriting = "Reading/Writing"
    case kinesthetic = "Kinesthetic"
    case balanced = "Balanced"

    var icon: String {
        switch self {
        case .visual: return "eye.fill"
        case .auditory: return "ear.fill"
        case .readingWriting: return "book.fill"
        case .kinesthetic: return "hand.raised.fill"
        case .balanced: return "circle.grid.2x2.fill"
        }
    }
}
