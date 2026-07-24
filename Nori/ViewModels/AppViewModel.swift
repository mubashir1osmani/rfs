import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var tasks = SeedData.tasks
    @Published var calendarBlocks = SeedData.calendar
    @Published var messages = [SeedData.welcomeMessage]
    @Published var composerText = ""
    @Published var isThinking = false
    @Published var actionStates: [String: ActionState] = [:]
    @Published var connections = ConnectionState()
    @Published var autonomyEnabled = true
    @Published var activeError: String?

    let speechRecognizer = SpeechRecognizer()
    private let assistantService: AssistantService
    private let integrationService: IntegrationService

    init(
        assistantService: AssistantService = AssistantService(),
        integrationService: IntegrationService = IntegrationService()
    ) {
        self.assistantService = assistantService
        self.integrationService = integrationService
    }

    var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    var nextEvent: CalendarBlock? {
        calendarBlocks
            .filter { $0.end >= Date() }
            .sorted { $0.start < $1.start }
            .first
    }

    var orderedEvents: [CalendarBlock] {
        calendarBlocks.sorted { $0.start < $1.start }
    }

    func send(_ preset: String? = nil) {
        let text = (preset ?? composerText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        composerText = ""
        selectedTab = .assistant
        messages.append(ChatMessage(id: UUID().uuidString, role: .user, text: text, actions: []))
        isThinking = true

        Task {
            let reply = await assistantService.ask(
                message: text,
                context: AssistantContext(tasks: tasks, calendar: calendarBlocks, currentDate: Date())
            )
            messages.append(ChatMessage(id: UUID().uuidString, role: .assistant, text: reply.message, actions: reply.actions))
            isThinking = false

            if autonomyEnabled {
                for action in reply.actions where action.kind == .task {
                    await execute(action, shouldUseIntegration: false)
                }
            }
        }
    }

    func runDemo() {
        send("Show me the Nori demo")
    }

    func execute(_ action: AssistantAction, shouldUseIntegration: Bool = true) async {
        do {
            switch action.kind {
            case .task:
                if !tasks.contains(where: { $0.id == action.id }) {
                    tasks.append(TaskItem(
                        id: action.id,
                        title: action.title ?? "New priority",
                        dueLabel: action.dueLabel ?? "Today",
                        category: action.category ?? .personal,
                        isCompleted: false
                    ))
                }
            case .calendar, .meeting:
                if shouldUseIntegration { try await integrationService.execute(action) }
                if !calendarBlocks.contains(where: { $0.id == action.id }) {
                    calendarBlocks.append(CalendarBlock(
                        id: action.id,
                        title: action.title ?? "Focus block",
                        start: action.startDate,
                        durationMinutes: action.durationMinutes ?? 60,
                        colorName: action.kind == .meeting ? "violet" : "blue",
                        source: .nori,
                        attendees: action.attendees ?? []
                    ))
                }
            case .email:
                if shouldUseIntegration { try await integrationService.execute(action) }
            }
            actionStates[action.id] = .completed
        } catch {
            activeError = error.localizedDescription
        }
    }

    func dismiss(_ action: AssistantAction) {
        actionStates[action.id] = .dismissed
    }

    func toggleTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
    }

    func addTask(title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        tasks.append(TaskItem(id: UUID().uuidString, title: cleanTitle, dueLabel: "Today", category: .personal, isCompleted: false))
    }

    func toggleConnection(_ keyPath: WritableKeyPath<ConnectionState, Bool>) {
        connections[keyPath: keyPath].toggle()
    }
}
