//
//  GroqService.swift
//  rufus
//
//  Created by AI Assistant
//

import Foundation
import Combine

@MainActor
class GroqService: ObservableObject {
    static let shared = GroqService()

    @Published var apiKey: String = ""
    @Published var hasValidApiKey: Bool = false

    let availableModels: [String: String] = [
        "llama3-70b-8192": "Llama 3 70B",
        "llama3-8b-8192": "Llama 3 8B",
        "mixtral-8x7b-32768": "Mixtral 8x7B"
    ]

    private init() {}

    func generateDailyBriefing(assignments: [Assignment], events: [CalendarEvent], courses: [Course]) async throws -> String {
        // Format assignments info
        let assignmentsText = assignments.isEmpty ? "No upcoming assignments" :
            assignments.map { "- \($0.title): Due \(formatDate($0.dueDate))" }.joined(separator: "\n")

        // Format events info
        let eventsText = events.isEmpty ? "No upcoming events" :
            events.prefix(5).map { "- \($0.title): \(formatDate($0.startDate))" }.joined(separator: "\n")

        // Format courses info
        let coursesText = courses.isEmpty ? "No courses" :
            courses.map { "- \($0.name)" }.joined(separator: "\n")

        // Generate briefing
        let briefing = """
        Good morning! Here's your daily briefing:

        📚 Courses:
        \(coursesText)

        📝 Upcoming Assignments:
        \(assignmentsText)

        📅 Calendar Events (Next 7 Days):
        \(eventsText)

        Have a productive day!
        """

        return briefing
    }

    func generateSmartReminder(for assignment: Assignment, with context: String) async throws -> String {
        // Simple reminder generation
        let reminder = """
        Reminder: \(assignment.title)
        Due: \(formatDate(assignment.dueDate))

        \(context)
        """
        return reminder
    }

    func generateAssistantResponse(prompt: String, conversationHistory: [ChatMessage]) async throws -> String {
        // Simple response generation
        return "I'm here to help! You said: \(prompt)"
    }

    func saveApiKey(_ key: String) {
        apiKey = key
        hasValidApiKey = !key.isEmpty
        KeychainHelper.shared.save(key, forKey: "groqApiKey")
    }

    func setSelectedModel(_ model: String) {
        UserDefaults.standard.set(model, forKey: "groqSelectedModel")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
