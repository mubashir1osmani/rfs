import Foundation

enum SeedData {
    static var tasks: [TaskItem] {
        [
            TaskItem(id: "task-1", title: "Finish product brief", dueLabel: "Today · 4:00 PM", category: .work, isCompleted: false),
            TaskItem(id: "task-2", title: "Review lecture notes", dueLabel: "Tonight · 30 min", category: .school, isCompleted: false),
            TaskItem(id: "task-3", title: "Call Mom", dueLabel: "Tonight", category: .personal, isCompleted: true),
        ]
    }

    static var calendar: [CalendarBlock] {
        [
            block(id: "event-1", title: "Deep work", hour: 9, minute: 0, duration: 90, color: "mint", protectionReason: "Project focus"),
            block(id: "event-2", title: "Team standup", hour: 11, minute: 0, duration: 30, color: "violet"),
            block(id: "event-3", title: "Lunch reset", hour: 12, minute: 30, duration: 45, color: "yellow", protectionReason: "Personal reset"),
        ]
    }

    static let welcomeMessage = ChatMessage(
        id: "welcome",
        role: .assistant,
        text: "Good morning — I’m Nori. Tell me what needs to happen, and I’ll turn it into tasks, calendar blocks, meetings, or ready-to-send emails.",
        actions: []
    )

    private static func block(
        id: String,
        title: String,
        hour: Int,
        minute: Int,
        duration: Int,
        color: String,
        protectionReason: String? = nil
    ) -> CalendarBlock {
        let start = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return CalendarBlock(
            id: id,
            title: title,
            start: start,
            durationMinutes: duration,
            colorName: color,
            source: .seed,
            attendees: [],
            protectionReason: protectionReason
        )
    }
}
