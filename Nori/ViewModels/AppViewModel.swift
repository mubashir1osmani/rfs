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
    @Published var autonomyEnabled = true
    @Published var activeError: String?

    let realtimeVoiceService: RealtimeVoiceService
    private let assistantService: AssistantService
    private let integrationService: IntegrationService
    private let stateStore: AppStateStore
    private var hasRestoredState = false
    private var persistenceRevision: UInt64 = 0
    private var pendingVoiceActions: [AssistantAction] = []

    init(
        assistantService: AssistantService = AssistantService(),
        integrationService: IntegrationService = IntegrationService(),
        stateStore: AppStateStore = AppStateStore(),
        realtimeVoiceService: RealtimeVoiceService = RealtimeVoiceService()
    ) {
        self.assistantService = assistantService
        self.integrationService = integrationService
        self.stateStore = stateStore
        self.realtimeVoiceService = realtimeVoiceService
        configureRealtimeVoice()
        Task { await restoreState() }
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
        persistState()
        isThinking = true

        Task {
            defer { isThinking = false }
            do {
                let reply = try await assistantService.ask(
                    message: text,
                    context: AssistantContext(tasks: tasks, calendar: calendarBlocks, currentDate: Date())
                )
                messages.append(ChatMessage(id: UUID().uuidString, role: .assistant, text: reply.message, actions: reply.actions))
                trimMessageHistory()

                if autonomyEnabled {
                    for action in reply.actions where action.kind == .task {
                        await execute(action, shouldUseIntegration: false)
                    }
                }
                persistState()
            } catch {
                activeError = error.localizedDescription
            }
        }
    }

    func runDemo() {
        send("Show me the Nori demo")
    }

    func toggleRealtimeVoice() {
        let context = AssistantContext(tasks: tasks, calendar: calendarBlocks, currentDate: Date())
        Task { await realtimeVoiceService.toggle(context: context) }
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
            persistState()
        } catch {
            activeError = error.localizedDescription
        }
    }

    func dismiss(_ action: AssistantAction) {
        actionStates[action.id] = .dismissed
        persistState()
    }

    func toggleTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        persistState()
    }

    func addTask(title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        tasks.append(TaskItem(id: UUID().uuidString, title: cleanTitle, dueLabel: "Today", category: .personal, isCompleted: false))
        persistState()
    }

    func setAutonomyEnabled(_ isEnabled: Bool) {
        autonomyEnabled = isEnabled
        persistState()
    }

    private func restoreState() async {
        defer { hasRestoredState = true }
        do {
            guard let state = try await stateStore.load() else { return }
            tasks = state.tasks
            calendarBlocks = state.calendarBlocks
            messages = state.messages.isEmpty ? [SeedData.welcomeMessage] : state.messages
            actionStates = state.actionStates
            autonomyEnabled = state.autonomyEnabled
            trimMessageHistory()
        } catch {
            activeError = "Your saved Nori data could not be loaded. A fresh session has been started."
        }
    }

    private func persistState() {
        guard hasRestoredState else { return }
        persistenceRevision += 1
        let revision = persistenceRevision
        let state = PersistedAppState(
            tasks: tasks,
            calendarBlocks: calendarBlocks,
            messages: Array(messages.suffix(100)),
            actionStates: actionStates,
            autonomyEnabled: autonomyEnabled
        )
        Task {
            do {
                try await stateStore.save(state, revision: revision)
            } catch {
                activeError = "Nori could not save your latest changes."
            }
        }
    }

    private func trimMessageHistory() {
        if messages.count > 100 {
            messages = Array(messages.suffix(100))
        }
    }

    private func configureRealtimeVoice() {
        realtimeVoiceService.onUserTranscript = { [weak self] transcript in
            guard let self else { return }
            selectedTab = .assistant
            messages.append(ChatMessage(id: UUID().uuidString, role: .user, text: transcript, actions: []))
            trimMessageHistory()
            persistState()
        }
        realtimeVoiceService.onAction = { [weak self] action in
            guard let self else { return }
            pendingVoiceActions.append(action)
            if autonomyEnabled, action.kind == .task {
                Task { await self.execute(action, shouldUseIntegration: false) }
            }
        }
        realtimeVoiceService.onAssistantTranscript = { [weak self] transcript in
            guard let self else { return }
            messages.append(ChatMessage(
                id: UUID().uuidString,
                role: .assistant,
                text: transcript,
                actions: pendingVoiceActions
            ))
            pendingVoiceActions = []
            trimMessageHistory()
            persistState()
        }
    }
}
