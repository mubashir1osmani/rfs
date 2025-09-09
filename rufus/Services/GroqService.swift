import Foundation
import SwiftUI
import SwiftData

class GroqService: ObservableObject {
    static let shared = GroqService()
    
    // MARK: - Properties
    @Published var isLoading = false
    @Published var lastResponse: String = ""
    
    private let apiBaseURL = "https://api.groq.com/openai/v1"
    private var apiKey: String? {
        return UserDefaults.standard.string(forKey: "groqApiKey")
    }
    
    // MARK: - Model Selection
    private var selectedModel: String {
        let savedModel = UserDefaults.standard.string(forKey: "groqSelectedModel") 
        return savedModel ?? "llama3-70b-8192"
    }
    
    // Available Groq models
    let availableModels = [
        "llama3-70b-8192": "Llama-3 70B",
        "llama3-8b-8192": "Llama-3 8B",
        "mixtral-8x7b-32768": "Mixtral 8x7B",
        "gemma-7b-it": "Gemma 7B"
    ]
    
    // MARK: - API Key Management
    func saveApiKey(_ key: String) {
        // Save securely to Keychain and remove any legacy UserDefaults value.
        KeychainHelper.shared.save(key, key: "groqApiKey")
        UserDefaults.standard.removeObject(forKey: "groqApiKey")
    }
    
    func hasValidApiKey() -> Bool {
        return apiKey?.isEmpty == false
    }
    
    func setSelectedModel(_ modelId: String) {
        UserDefaults.standard.set(modelId, forKey: "groqSelectedModel")
    }
    
    struct Message: Codable, Identifiable {
        var id = UUID()
        let role: String
        let content: String
        
        enum CodingKeys: String, CodingKey {
            case role, content
        }
    }
    
    struct CompletionRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }
    
    struct CompletionResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let role: String
                let content: String
            }
            let message: Message
        }
        
        let choices: [Choice]
    }
    
    // MARK: - LLM Interactions
    func generateAssistantResponse(prompt: String, context: [String: Any]) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw NSError(domain: "GroqService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key not configured"])
        }
        
        let messages = buildMessages(prompt: prompt, context: context)
        
        let requestBody = CompletionRequest(
            model: selectedModel,
            messages: messages,
            temperature: 0.7,
            max_tokens: 2048
        )
        
        guard let url = URL(string: "\(apiBaseURL)/chat/completions") else {
            throw NSError(domain: "GroqService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GroqService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, 
                          userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"])
        }
        
        let decoder = JSONDecoder()
        let completionResponse = try decoder.decode(CompletionResponse.self, from: data)
        
        guard let assistantMessage = completionResponse.choices.first?.message else {
            throw NSError(domain: "GroqService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from LLM"])
        }
        
        return assistantMessage.content
    }
    
    // MARK: - Helper Methods
    private func buildMessages(prompt: String, context: [String: Any]) -> [Message] {
        var messages: [Message] = []
        
        // System prompt with basic instructions
        let systemPrompt = """
        You are Rufus, a helpful AI assistant in a student productivity app. 
        You have access to the user's calendar events, assignments, and courses.
        Provide clear, concise, and helpful responses about their academic schedule and tasks.
        Always prioritize upcoming deadlines and important events in your responses.
        """
        
        messages.append(Message(role: "system", content: systemPrompt))
        
        if let contextString = formatContextString(context: context) {
            messages.append(Message(role: "system", content: contextString))
        }
        
        // Add user query
        messages.append(Message(role: "user", content: prompt))
        
        return messages
    }
    
    private func formatContextString(context: [String: Any]) -> String? {
        var contextString = "Here's the current context about the user's data:\n\n"
        
        if let assignments = context["assignments"] as? [Assignment] {
            contextString += "ASSIGNMENTS:\n"
            
            if assignments.isEmpty {
                contextString += "No assignments found.\n"
            } else {
                for assignment in assignments {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    
                    let status = assignment.isCompleted ? "COMPLETED" : "PENDING"
                    let courseName = assignment.course?.name ?? "No Course"
                    
                    contextString += "- \(assignment.title) (\(courseName))\n"
                    contextString += "  Due: \(dateFormatter.string(from: assignment.dueDate))\n"
                    contextString += "  Priority: \(assignment.priority.rawValue)\n"
                    contextString += "  Status: \(status)\n"
                    
                    if !assignment.assignmentDescription.isEmpty {
                        contextString += "  Description: \(assignment.assignmentDescription)\n"
                    }
                    contextString += "\n"
                }
            }
        }
        
        if let events = context["calendarEvents"] as? [CalendarEvent] {
            contextString += "CALENDAR EVENTS:\n"
            
            if events.isEmpty {
                contextString += "No calendar events found.\n"
            } else {
                for event in events {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    
                    contextString += "- \(event.title)\n"
                    contextString += "  Start: \(dateFormatter.string(from: event.startDate))\n"
                    contextString += "  End: \(dateFormatter.string(from: event.endDate))\n"
                    contextString += "  Source: \(event.source)\n"
                    
                    if let location = event.location, !location.isEmpty {
                        contextString += "  Location: \(location)\n"
                    }
                    contextString += "\n"
                }
            }
        }
        
        if let courses = context["courses"] as? [Course] {
            contextString += "COURSES:\n"
            
            if courses.isEmpty {
                contextString += "No courses found.\n"
            } else {
                for course in courses {
                    contextString += "- \(course.displayName)\n"
                    if !course.professor.isEmpty {
                        contextString += "  Professor: \(course.professor)\n"
                    }
                    
                    let assignmentCount = course.assignments.count
                    let pendingCount = course.assignments.filter { !$0.isCompleted }.count
                    
                    contextString += "  Assignments: \(assignmentCount) total, \(pendingCount) pending\n\n"
                }
            }
        }
        
        return contextString
    }
    
    func generateSmartReminder(for assignment: Assignment, courses: [Course]) async throws -> String {
        let context: [String: Any] = [
            "assignments": [assignment],
            "courses": courses
        ]
        
        let prompt = """
        Generate a smart reminder for this assignment that includes:
        1. How much time is remaining until the deadline
        2. A brief motivational message about completing it early
        3. A suggestion about how to approach this assignment based on its description and subject
        Keep it brief (maximum 3 sentences) but informative and motivational.
        """
        
        return try await generateAssistantResponse(prompt: prompt, context: context)
    }
    
    func generateDailyBriefing(assignments: [Assignment], events: [CalendarEvent], courses: [Course]) async throws -> String {
        let context: [String: Any] = [
            "assignments": assignments,
            "calendarEvents": events,
            "courses": courses
        ]
        
        let prompt = """
        Generate a daily briefing for today that includes:
        1. A summary of upcoming assignments (prioritize by due date and importance)
        2. Today's schedule/events
        3. A brief note about overall workload and key priorities
        Focus on the most important items and keep it concise and actionable.
        """
        
        return try await generateAssistantResponse(prompt: prompt, context: context)
    }
}
