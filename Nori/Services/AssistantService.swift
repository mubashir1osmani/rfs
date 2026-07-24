import Foundation

enum AssistantServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Nori received an invalid response. Please try again."
        case let .requestFailed(message): message
        }
    }
}

actor AssistantService {
    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }

        let choices: [Choice]
    }

    private let configuration: AppConfiguration

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    func ask(message: String, context: AssistantContext) async throws -> AssistantReply {
        guard configuration.usesRemoteAssistant else {
            return localReply(message: message, context: context)
        }
        return try await remoteReply(message: message, context: context)
    }

    private func remoteReply(message: String, context: AssistantContext) async throws -> AssistantReply {
        guard let apiKey = configuration.openAIKey else { throw AssistantServiceError.invalidResponse }
        var request = URLRequest(url: configuration.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let contextData = try JSONEncoder.nori.encode(context)
        let contextJSON = String(data: contextData, encoding: .utf8) ?? "{}"
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-5.6-sol",
            "messages": [
                ["role": "system", "content": Self.instructions],
                ["role": "user", "content": "Request: \(message)\nContext: \(contextJSON)"],
            ],
            "reasoning_effort": "low",
            "safety_identifier": configuration.userID,
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "nori_action_plan",
                    "strict": true,
                    "schema": Self.replySchema,
                ],
            ],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw AssistantServiceError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            throw AssistantServiceError.requestFailed(errorMessage(from: data, statusCode: httpResponse.statusCode))
        }
        do {
            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = response.choices.first?.message.content.data(using: .utf8) else {
                throw AssistantServiceError.invalidResponse
            }
            return try JSONDecoder().decode(AssistantReply.self, from: content)
        } catch {
            throw AssistantServiceError.invalidResponse
        }
    }

    private static let instructions = """
    You are Nori, an action-oriented personal assistant for students and working professionals.
    Return a short helpful message and zero or more typed actions. Use ISO 8601 timestamps with timezone offsets.
    Tasks are safe local actions. Calendar changes, meeting invitations, and emails must remain visible for approval.
    Never claim an external action happened. Draft concise professional emails and avoid overlapping calendar events.
    """

    private static var replySchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "message": ["type": "string"],
                "actions": [
                    "type": "array",
                    "maxItems": 5,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "kind": ["type": "string", "enum": ["task", "calendar", "meeting", "email"]],
                            "title": ["type": ["string", "null"]],
                            "dueLabel": ["type": ["string", "null"]],
                            "category": ["type": ["string", "null"], "enum": ["Work", "School", "Personal", NSNull()]],
                            "start": ["type": ["string", "null"]],
                            "durationMinutes": ["type": ["integer", "null"]],
                            "notes": ["type": ["string", "null"]],
                            "attendees": ["type": ["array", "null"], "items": ["type": "string"]],
                            "to": ["type": ["string", "null"]],
                            "subject": ["type": ["string", "null"]],
                            "body": ["type": ["string", "null"]],
                        ],
                        "required": ["id", "kind", "title", "dueLabel", "category", "start", "durationMinutes", "notes", "attendees", "to", "subject", "body"],
                    ],
                ],
            ],
            "required": ["message", "actions"],
        ]
    }

    private func errorMessage(from data: Data, statusCode: Int) -> String {
        struct ErrorEnvelope: Decodable {
            struct APIError: Decodable { let message: String }
            let error: APIError
        }
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return envelope.error.message
        }
        return "Nori’s service is unavailable (\(statusCode)). Please try again."
    }

    private func localReply(message: String, context: AssistantContext) -> AssistantReply {
        let lowercased = message.lowercased()
        if lowercased.contains("nori demo") || lowercased.contains("show me the demo") {
            return demoReply()
        }
        if lowercased.contains("plan") || lowercased.contains("organize") || lowercased.contains("time block my day") {
            return dayPlan(context: context)
        }
        if lowercased.contains("email") || lowercased.contains("write to") {
            let recipient = firstEmail(in: message) ?? ""
            let body = value(after: "that", in: message) ?? "Hi,\n\nJust following up. Let me know what works for you.\n\nBest,"
            return AssistantReply(
                message: "I drafted the email. You’ll review it before anything is sent.",
                actions: [.email(to: recipient, subject: "Quick follow-up", body: body)]
            )
        }
        if lowercased.contains("meeting") || lowercased.contains("book") || lowercased.contains("call with") {
            let action = calendarAction(message: message, kind: .meeting)
            return AssistantReply(message: "I prepared the meeting invite with a practical time and duration.", actions: [action])
        }
        if lowercased.contains("schedule") || lowercased.contains("calendar") || lowercased.contains("focus block") || lowercased.contains("study session") {
            let action = calendarAction(message: message, kind: .calendar)
            return AssistantReply(message: "I found a clean spot and prepared a protected calendar block.", actions: [action])
        }

        return AssistantReply(
            message: "Got it. I turned that into a priority so it doesn’t get lost.",
            actions: [.task(title: cleanTitle(message), dueLabel: lowercased.contains("tomorrow") ? "Tomorrow" : "Today", category: category(for: message))]
        )
    }

    private func dayPlan(context: AssistantContext) -> AssistantReply {
        let hours = [9, 11, 14]
        let actions = context.tasks
            .filter { !$0.isCompleted }
            .prefix(3)
            .enumerated()
            .map { index, task in
                AssistantAction.calendar(
                    title: task.title,
                    start: date(hour: hours[index], minute: index == 1 ? 30 : 0),
                    durationMinutes: task.category == .personal ? 30 : 60,
                    notes: "Time block for \(task.category.rawValue.lowercased()) priority"
                )
            }
        let message = actions.isEmpty
            ? "Your task list is clear. Add a priority and I’ll build the day around it."
            : "I made a realistic \(actions.count)-block plan with breathing room. Review the blocks before adding them."
        return AssistantReply(message: message, actions: actions)
    }

    private func demoReply() -> AssistantReply {
        AssistantReply(
            message: "Here’s Nori in action: a task, focus block, meeting invite, and email draft. External actions stay ready for your approval.",
            actions: [
                .task(title: "Review tomorrow’s priorities", dueLabel: "Today · 10 min", category: .personal),
                .calendar(title: "Deep work · Project brief", start: date(hour: 9, minute: 30, dayOffset: 1), durationMinutes: 90, notes: "Protected focus block planned by Nori"),
                .calendar(kind: .meeting, title: "Weekly project sync", start: date(hour: 14, minute: 0, dayOffset: 1), durationMinutes: 30, notes: "Weekly project check-in", attendees: ["alex@example.com"]),
                .email(to: "alex@example.com", subject: "Tomorrow’s project sync", body: "Hi Alex,\n\nDoes 2:00 PM tomorrow work for our project sync?\n\nBest,\nMubashir"),
            ]
        )
    }

    private func calendarAction(message: String, kind: AssistantAction.Kind) -> AssistantAction {
        let components = timeComponents(in: message)
        let dayOffset = message.localizedCaseInsensitiveContains("tomorrow") ? 1 : 0
        return .calendar(
            kind: kind,
            title: cleanTitle(message),
            start: date(hour: components.hour, minute: components.minute, dayOffset: dayOffset),
            durationMinutes: duration(in: message, fallback: kind == .meeting ? 30 : 60),
            notes: kind == .meeting ? "Meeting organized with Nori" : "Protected focus time planned with Nori",
            attendees: firstEmail(in: message).map { [$0] } ?? []
        )
    }

    private func timeComponents(in message: String) -> (hour: Int, minute: Int) {
        let pattern = #"(?i)(?:at|around)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let hourRange = Range(match.range(at: 1), in: message) else { return (14, 0) }
        var hour = Int(message[hourRange]) ?? 14
        let minute = Range(match.range(at: 2), in: message).flatMap { Int(message[$0]) } ?? 0
        let meridiem = Range(match.range(at: 3), in: message).map { message[$0].lowercased() }
        if meridiem == "pm" && hour < 12 { hour += 12 }
        if meridiem == "am" && hour == 12 { hour = 0 }
        if meridiem == nil && hour < 8 { hour += 12 }
        return (min(hour, 23), minute)
    }

    private func duration(in message: String, fallback: Int) -> Int {
        let pattern = #"(?i)(\d+)\s*(min|minute|hour|hr)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let valueRange = Range(match.range(at: 1), in: message),
              let unitRange = Range(match.range(at: 2), in: message) else { return fallback }
        let value = Int(message[valueRange]) ?? fallback
        return message[unitRange].lowercased().hasPrefix("h") ? value * 60 : value
    }

    private func cleanTitle(_ message: String) -> String {
        let patterns = [
            #"(?i)\b(add|create|schedule|block|book|please|for me|on my calendar|to my calendar)\b"#,
            #"(?i)\b(today|tomorrow|tonight|this afternoon|this morning)\b"#,
            #"(?i)\b(?:at|around)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?"#,
            #"(?i)\bfor\s+\d+\s*(?:min(?:ute)?s?|h(?:ou)?rs?)\b"#,
        ]
        let result = patterns.reduce(message) { current, pattern in
            current.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "New priority" : result
    }

    private func firstEmail(in message: String) -> String? {
        let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        guard let range = message.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return String(message[range])
    }

    private func value(after word: String, in message: String) -> String? {
        guard let range = message.range(of: "\(word) ", options: .caseInsensitive) else { return nil }
        let value = message[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func category(for message: String) -> TaskItem.Category {
        let lowercased = message.lowercased()
        if ["study", "class", "lecture", "exam", "assignment", "school"].contains(where: lowercased.contains) { return .school }
        if ["work", "client", "team", "project", "brief", "report"].contains(where: lowercased.contains) { return .work }
        return .personal
    }

    private func date(hour: Int, minute: Int, dayOffset: Int = 0) -> Date {
        let targetDay = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay) ?? targetDay
    }
}

extension JSONEncoder {
    static var nori: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var nori: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
