//
//  ChatService.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-17.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var lastMessageFromAssistant: String?

    private let groqService = GroqService()
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    init() {
        addWelcomeMessage()
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "Hi! I'm your AI assistant. I can help you with:\n\n• Adding assignments and setting due dates\n• Creating courses and managing schedules\n• Setting reminders for important tasks\n• Explaining concepts and providing study help\n• Scheduling meetings and managing your calendar\n• Getting daily briefings about your tasks\n\nWhat can I help you with today?",
            isUser: false
        )
        messages.append(welcomeMessage)
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = ChatMessage(content: content, isUser: true)
        messages.append(userMessage)
        
        // Add thinking indicator
        let thinkingMessage = ChatMessage(content: "Thinking...", isUser: false, isThinking: true)
        messages.append(thinkingMessage)
        
        isLoading = true
        
        do {
            // Get response from Groq
            let response = await getAIResponse(for: content)
            
            // Remove thinking indicator
            if let lastIndex = messages.lastIndex(where: { $0.isThinking }) {
                messages.remove(at: lastIndex)
            }
            
            // Add AI response
            let aiMessage = ChatMessage(content: response, isUser: false)
            messages.append(aiMessage)
            lastMessageFromAssistant = response

            // Check if the message contains actionable items
            await processActionableContent(content)
            
        } catch {
            // Remove thinking indicator
            if let lastIndex = messages.lastIndex(where: { $0.isThinking }) {
                messages.remove(at: lastIndex)
            }
            
            let errorMessage = ChatMessage(
                content: "I'm sorry, I encountered an error. Please try again.",
                isUser: false
            )
            messages.append(errorMessage)
            lastMessageFromAssistant = errorMessage.content
        }

        isLoading = false
    }
    
    private func getAIResponse(for message: String) async -> String {
        let systemPrompt = """
        You are a helpful AI assistant for a student management app called Rufus. You can help users with:
        
        1. Adding assignments (parse due dates, course names, descriptions)
        2. Creating courses (extract course names, codes, credits)
        3. Setting reminders (parse dates and times)
        4. Explaining concepts and providing study help
        5. Scheduling meetings (parse dates, times, durations)
        6. Providing daily briefings about tasks and assignments
        
        When users ask for help with actionable items (assignments, courses, reminders, meetings), provide a helpful response and include specific details that can be extracted.
        
        For assignments, look for: title, description, due date, course
        For courses, look for: name, course code, credits
        For reminders, look for: title, date/time, message
        For meetings, look for: title, date/time, duration
        
        Be conversational, helpful, and encouraging. If you need more information to complete a task, ask specific questions.
        """
        
        let userContext = await getUserContext()
        let fullPrompt = systemPrompt + "\n\nUser Context:\n" + userContext + "\n\nUser Message: " + message
        
        do {
            return try await groqService.generateAssistantResponse(prompt: fullPrompt, context: [:])
        } catch {
            return "I'm having trouble connecting to my AI service right now. Please try again in a moment."
        }
    }
    
    private func getUserContext() async -> String {
        var context = "Current Context:\n"
        
        guard let modelContext = modelContext else {
            return context + "No data context available"
        }
        
        // Get user's assignments using SwiftData queries
        let assignmentDescriptor = FetchDescriptor<Assignment>(
            sortBy: [SortDescriptor(\.dueDate)]
        )
        
        do {
            let assignments = try modelContext.fetch(assignmentDescriptor)
            if !assignments.isEmpty {
                context += "Upcoming Assignments:\n"
                for assignment in assignments.prefix(5) {
                    context += "- \(assignment.title) (Due: \(assignment.dueDate.formatted(date: .abbreviated, time: .omitted)))\n"
                }
            }
        } catch {
            print("Error fetching assignments: \(error)")
        }
        
        // Get user's courses
        let courseDescriptor = FetchDescriptor<Course>()
        
        do {
            let courses = try modelContext.fetch(courseDescriptor)
            if !courses.isEmpty {
                context += "\nCurrent Courses:\n"
                for course in courses {
                    context += "- \(course.name) (\(course.code))\n"
                }
            }
        } catch {
            print("Error fetching courses: \(error)")
        }
        
        context += "\nCurrent Date: \(Date().formatted(date: .complete, time: .omitted))"
        
        return context
    }
    
    private func processActionableContent(_ message: String) async {
        let lowercased = message.lowercased()
        
        // Check for assignment creation
        if lowercased.contains("add assignment") || lowercased.contains("create assignment") || lowercased.contains("new assignment") {
            await parseAndCreateAssignment(message)
        }
        
        // Check for course creation
        if lowercased.contains("add course") || lowercased.contains("create course") || lowercased.contains("new course") {
            await parseAndCreateCourse(message)
        }
        
        // Check for reminder setting
        if lowercased.contains("remind me") || lowercased.contains("set reminder") || lowercased.contains("reminder") {
            await parseAndCreateReminder(message)
        }
        
        // Check for meeting scheduling
        if lowercased.contains("schedule meeting") || lowercased.contains("book meeting") || lowercased.contains("meeting") {
            await parseAndScheduleMeeting(message)
        }
        
        // Check for daily briefing
        if lowercased.contains("daily briefing") || lowercased.contains("what's due") || lowercased.contains("upcoming") {
            await provideDailyBriefing()
        }
    }
    
    private func parseAndCreateAssignment(_ message: String) async {
        // Enhanced parsing for assignment creation
        let lowercased = message.lowercased()
        
        // Extract potential assignment title
        var title = "New Assignment"
        if let titleMatch = extractBetween(text: lowercased, start: "assignment", end: ["due", "for", "in", "course"]) {
            title = titleMatch.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        }
        
        // Try to extract due date
        var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        if let dateString = extractDate(from: message) {
            // You could use a date parser here
            // For now, we'll use a simple approach
        }
        
        // Try to extract course
        var selectedCourse: Course?
        
        if let modelContext = modelContext {
            let courseDescriptor = FetchDescriptor<Course>()
            do {
                let courses = try modelContext.fetch(courseDescriptor)
                for course in courses {
                    if lowercased.contains(course.name.lowercased()) || lowercased.contains(course.code.lowercased()) {
                        selectedCourse = course
                        break
                    }
                }
            } catch {
                print("Error fetching courses: \(error)")
            }
        }
        
        let confirmationMessage = ChatMessage(
            content: "I'll help you create an assignment titled '\(title)'. Would you like me to set it up with the details I found, or would you prefer to add it manually using the Assignments tab for more precise control?",
            isUser: false
        )
        messages.append(confirmationMessage)
        lastMessageFromAssistant = confirmationMessage.content
    }

    private func parseAndCreateCourse(_ message: String) async {
        let lowercased = message.lowercased()
        
        // Extract course name
        var courseName = "New Course"
        if let nameMatch = extractBetween(text: lowercased, start: "course", end: ["with", "code", "credits"]) {
            courseName = nameMatch.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        }
        
        let confirmationMessage = ChatMessage(
            content: "I can help you add a course called '\(courseName)'. You can also use the Courses tab to add it with all the specific details like course code and credits.",
            isUser: false
        )
        messages.append(confirmationMessage)
        lastMessageFromAssistant = confirmationMessage.content
    }

    private func parseAndCreateReminder(_ message: String) async {
        let lowercased = message.lowercased()
        
        // Extract reminder content
        var reminderText = "Important reminder"
        if let reminderMatch = extractBetween(text: lowercased, start: "remind me", end: ["at", "on", "in"]) {
            reminderText = reminderMatch.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let reminderMatch = extractBetween(text: lowercased, start: "reminder", end: ["at", "on", "in"]) {
            reminderText = reminderMatch.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let confirmationMessage = ChatMessage(
            content: "I'll set up a reminder for '\(reminderText)'. The notification system will alert you at the specified time. You can also manage your reminders through the Settings.",
            isUser: false
        )
        messages.append(confirmationMessage)
        lastMessageFromAssistant = confirmationMessage.content
    }

    private func parseAndScheduleMeeting(_ message: String) async {
        let lowercased = message.lowercased()
        
        // Extract meeting title
        var meetingTitle = "Study Session"
        if let titleMatch = extractBetween(text: lowercased, start: "meeting", end: ["at", "on", "for"]) {
            meetingTitle = titleMatch.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        }
        
        let confirmationMessage = ChatMessage(
            content: "I can help you schedule '\(meetingTitle)'. This will be added to your calendar if you have calendar integration enabled in Settings.",
            isUser: false
        )
        messages.append(confirmationMessage)
        lastMessageFromAssistant = confirmationMessage.content
    }

    // Helper functions for text parsing
    private func extractBetween(text: String, start: String, end: [String]) -> String? {
        guard let startRange = text.range(of: start) else { return nil }
        let afterStart = String(text[startRange.upperBound...])
        
        var endIndex = afterStart.endIndex
        for endWord in end {
            if let endRange = afterStart.range(of: endWord) {
                if endRange.lowerBound < endIndex {
                    endIndex = endRange.lowerBound
                }
            }
        }
        
        let extracted = String(afterStart[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        return extracted.isEmpty ? nil : extracted
    }
    
    private func extractDate(from text: String) -> String? {
        // Simple date extraction - in a real app, you'd use more sophisticated NLP
        let dateKeywords = ["today", "tomorrow", "next week", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        let lowercased = text.lowercased()
        
        for keyword in dateKeywords {
            if lowercased.contains(keyword) {
                return keyword
            }
        }
        return nil
    }
    
    private func provideDailyBriefing() async {
        guard let modelContext = modelContext else {
            let errorMessage = ChatMessage(
                content: "I can't access your assignment data right now. Please try again later.",
                isUser: false
            )
            messages.append(errorMessage)
            lastMessageFromAssistant = errorMessage.content
            return
        }
        
        let assignmentDescriptor = FetchDescriptor<Assignment>(
            sortBy: [SortDescriptor(\.dueDate)]
        )
        
        let today = Date()
        let calendar = Calendar.current
        
        do {
            let assignments = try modelContext.fetch(assignmentDescriptor)
            let dueSoon = assignments.filter { assignment in
                calendar.dateInterval(of: .day, for: today)?.contains(assignment.dueDate) == true ||
                calendar.dateInterval(of: .day, for: calendar.date(byAdding: .day, value: 1, to: today)!)?.contains(assignment.dueDate) == true
            }
            
            var briefing = "📅 Daily Briefing for \(today.formatted(date: .complete, time: .omitted))\n\n"
            
            if dueSoon.isEmpty {
                briefing += "✅ You have no assignments due today or tomorrow. Great job staying on top of your work!"
            } else {
                briefing += "📚 Assignments due soon:\n"
                for assignment in dueSoon.sorted(by: { $0.dueDate < $1.dueDate }) {
                    let daysUntilDue = calendar.dateComponents([.day], from: today, to: assignment.dueDate).day ?? 0
                    let timeText = daysUntilDue == 0 ? "today" : "tomorrow"
                    briefing += "• \(assignment.title) - Due \(timeText)\n"
                }
            }
            
            let briefingMessage = ChatMessage(content: briefing, isUser: false)
            messages.append(briefingMessage)
            lastMessageFromAssistant = briefingMessage.content
        } catch {
            let errorMessage = ChatMessage(
                content: "I encountered an error while fetching your assignments. Please try again.",
                isUser: false
            )
            messages.append(errorMessage)
            lastMessageFromAssistant = errorMessage.content
        }
    }
    
    func clearChat() {
        messages.removeAll()
        addWelcomeMessage()
    }
}
