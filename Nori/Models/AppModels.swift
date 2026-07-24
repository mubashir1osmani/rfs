import Foundation

enum AppTab: Hashable {
    case home
    case assistant
    case day
    case settings
}

struct TaskItem: Identifiable, Codable, Hashable, Sendable {
    enum Category: String, Codable, CaseIterable, Sendable {
        case work = "Work"
        case school = "School"
        case personal = "Personal"
    }

    let id: String
    var title: String
    var dueLabel: String
    var category: Category
    var isCompleted: Bool
}

struct CalendarBlock: Identifiable, Codable, Hashable, Sendable {
    enum Source: String, Codable, Sendable {
        case seed
        case nori
    }

    let id: String
    var title: String
    var start: Date
    var durationMinutes: Int
    var colorName: String
    var source: Source
    var attendees: [String]

    var end: Date {
        start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
}

struct AssistantAction: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case task
        case calendar
        case meeting
        case email
    }

    let id: String
    let kind: Kind
    var title: String? = nil
    var dueLabel: String? = nil
    var category: TaskItem.Category? = nil
    var start: String? = nil
    var durationMinutes: Int? = nil
    var notes: String? = nil
    var attendees: [String]? = nil
    var to: String? = nil
    var subject: String? = nil
    var body: String? = nil

    var startDate: Date {
        guard let start else { return Date().addingTimeInterval(3600) }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: start) { return date }
        return ISO8601DateFormatter().date(from: start) ?? Date().addingTimeInterval(3600)
    }

    static func task(title: String, dueLabel: String, category: TaskItem.Category) -> AssistantAction {
        AssistantAction(id: UUID().uuidString, kind: .task, title: title, dueLabel: dueLabel, category: category)
    }

    static func calendar(
        kind: Kind = .calendar,
        title: String,
        start: Date,
        durationMinutes: Int,
        notes: String,
        attendees: [String] = []
    ) -> AssistantAction {
        AssistantAction(
            id: UUID().uuidString,
            kind: kind,
            title: title,
            start: start.ISO8601Format(),
            durationMinutes: durationMinutes,
            notes: notes,
            attendees: attendees
        )
    }

    static func email(to: String, subject: String, body: String) -> AssistantAction {
        AssistantAction(id: UUID().uuidString, kind: .email, to: to, subject: subject, body: body)
    }
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    enum Role: Hashable, Sendable {
        case assistant
        case user
    }

    let id: String
    let role: Role
    let text: String
    var actions: [AssistantAction]
}

struct AssistantContext: Codable, Sendable {
    let tasks: [TaskItem]
    let calendar: [CalendarBlock]
    let currentDate: Date
}

struct AssistantReply: Codable, Sendable {
    let message: String
    let actions: [AssistantAction]
}

enum ActionState: Hashable, Sendable {
    case completed
    case dismissed
}

struct ConnectionState: Sendable {
    var calendar = false
    var gmail = false
}
