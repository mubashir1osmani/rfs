//
//  ChatMessage.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-17.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var isThinking: Bool = false
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), isThinking: Bool = false) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isThinking = isThinking
    }
}

enum ChatAction {
    case addAssignment(title: String, description: String, dueDate: Date, courseId: String?)
    case addCourse(name: String, code: String, credits: Int)
    case setReminder(title: String, date: Date, message: String)
    case explainConcept(topic: String)
    case scheduleMeeting(title: String, date: Date, duration: Int)
    case checkAssignments
    case getDailyBriefing
}

struct ChatActionResult {
    let success: Bool
    let message: String
    let action: ChatAction?
}
