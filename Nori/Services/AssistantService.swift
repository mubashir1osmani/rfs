import Foundation

actor AssistantService {
    private struct Request: Encodable {
        let message: String
        let context: AssistantContext
    }

    private let configuration: AppConfiguration

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    func ask(message: String, context: AssistantContext) async -> AssistantReply {
        if let remoteReply = await remoteReply(message: message, context: context) {
            return remoteReply
        }
        return localReply(message: message, context: context)
    }

    private func remoteReply(message: String, context: AssistantContext) async -> AssistantReply? {
        guard let url = configuration.assistantURL else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.userID, forHTTPHeaderField: "X-User-Id")
        if let appToken = configuration.appToken {
            request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder.nori.encode(Request(message: message, context: context))

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }
        return try? JSONDecoder.nori.decode(AssistantReply.self, from: data)
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

private extension JSONEncoder {
    static var nori: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var nori: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
