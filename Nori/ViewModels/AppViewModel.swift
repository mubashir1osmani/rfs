import Combine
import EventKit
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
    @Published var proactiveAlertsEnabled = true
    @Published private(set) var conflicts: [ScheduleConflict] = []
    @Published private(set) var calendarAccessGranted = false
    @Published private(set) var calendarConnected = false
    @Published private(set) var isRefreshingSchedule = false
    @Published var activeError: String?

    let realtimeVoiceService: RealtimeVoiceService
    private let assistantService: AssistantService
    private let integrationService: IntegrationService
    private let conflictDetector: ConflictDetector
    private let proactiveNotifications: ProactiveNotificationService
    private let stateStore: AppStateStore
    private var hasRestoredState = false
    private var persistenceRevision: UInt64 = 0
    private var pendingVoiceActions: [AssistantAction] = []
    private var calendarChangeSubscription: AnyCancellable?

    init(
        assistantService: AssistantService = AssistantService(),
        integrationService: IntegrationService = IntegrationService(),
        conflictDetector: ConflictDetector = ConflictDetector(),
        proactiveNotifications: ProactiveNotificationService = ProactiveNotificationService(),
        stateStore: AppStateStore = AppStateStore(),
        realtimeVoiceService: RealtimeVoiceService = RealtimeVoiceService()
    ) {
        self.assistantService = assistantService
        self.integrationService = integrationService
        self.conflictDetector = conflictDetector
        self.proactiveNotifications = proactiveNotifications
        self.stateStore = stateStore
        self.realtimeVoiceService = realtimeVoiceService
        calendarAccessGranted = integrationService.hasSystemCalendarAccess
        calendarConnected = integrationService.hasCalendarConnection
        configureRealtimeVoice()
        observeCalendarChanges()
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

    var todayEvents: [CalendarBlock] {
        orderedEvents.filter { Calendar.current.isDateInToday($0.start) }
    }

    var protectedBlocks: [CalendarBlock] {
        orderedEvents.filter(\.isProtected)
    }

    var protectedBlocksToday: [CalendarBlock] {
        protectedBlocks.filter { Calendar.current.isDateInToday($0.start) }
    }

    var protectedMinutesToday: Int {
        protectedBlocksToday.reduce(0) { $0 + $1.durationMinutes }
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

    func connectSystemCalendar() {
        Task {
            do {
                calendarAccessGranted = try await integrationService.requestSystemCalendarAccess()
                guard calendarAccessGranted else {
                    activeError = "Calendar access is required to watch protected time."
                    return
                }
                await refreshSchedule()
            } catch {
                activeError = error.localizedDescription
            }
        }
    }

    func refreshSchedule() async {
        calendarConnected = integrationService.hasCalendarConnection
        guard calendarConnected else {
            calendarBlocks.removeAll { $0.source == .google || $0.source == .system }
            updateConflicts()
            persistState()
            return
        }
        guard !isRefreshingSchedule else { return }
        isRefreshingSchedule = true
        defer { isRefreshingSchedule = false }
        calendarAccessGranted = integrationService.hasSystemCalendarAccess

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) ?? Date()
        let end = calendar.date(byAdding: .day, value: 15, to: start) ?? Date().addingTimeInterval(15 * 86_400)
        let fetched = await integrationService.calendarBlocks(from: start, to: end)
        mergeCalendarBlocks(fetched, from: start, to: end)
        updateConflicts()
        persistState()
        if proactiveAlertsEnabled {
            await proactiveNotifications.sync(protectedBlocks: protectedBlocks, conflicts: conflicts)
        }
    }

    func setProtection(_ block: CalendarBlock, reason: String?) {
        guard let index = calendarBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        calendarBlocks[index].protectionReason = reason
        updateConflicts()
        persistState()
        guard proactiveAlertsEnabled else { return }
        Task {
            if reason != nil {
                do {
                    try await proactiveNotifications.enable(protectedBlocks: protectedBlocks, conflicts: conflicts)
                } catch {
                    activeError = "Nori could not enable proactive notifications."
                }
            } else {
                await proactiveNotifications.sync(protectedBlocks: protectedBlocks, conflicts: conflicts)
            }
        }
    }

    func resolve(_ conflict: ScheduleConflict) {
        send("Give me concise options for this conflict without moving my protected block. Do not create an action until I choose: \(conflict.summary)")
    }

    func setProactiveAlertsEnabled(_ isEnabled: Bool) {
        proactiveAlertsEnabled = isEnabled
        persistState()
        Task {
            if isEnabled {
                do {
                    try await proactiveNotifications.enable(protectedBlocks: protectedBlocks, conflicts: conflicts)
                } catch {
                    activeError = "Nori could not enable proactive notifications."
                }
            } else {
                await proactiveNotifications.disable()
            }
        }
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
                        attendees: action.attendees ?? [],
                        protectionReason: action.protectionReason
                    ))
                }
            case .email:
                if shouldUseIntegration { try await integrationService.execute(action) }
            }
            actionStates[action.id] = .completed
            updateConflicts()
            persistState()
            if proactiveAlertsEnabled {
                await proactiveNotifications.sync(protectedBlocks: protectedBlocks, conflicts: conflicts)
            }
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
        do {
            if let state = try await stateStore.load() {
                tasks = state.tasks
                calendarBlocks = state.calendarBlocks
                messages = state.messages.isEmpty ? [SeedData.welcomeMessage] : state.messages
                actionStates = state.actionStates
                autonomyEnabled = state.autonomyEnabled
                proactiveAlertsEnabled = state.proactiveAlertsEnabled ?? true
                trimMessageHistory()
            }
        } catch {
            activeError = "Your saved Nori data could not be loaded. A fresh session has been started."
        }
        hasRestoredState = true
        updateConflicts()
        await refreshSchedule()
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
            autonomyEnabled: autonomyEnabled,
            proactiveAlertsEnabled: proactiveAlertsEnabled
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

    private func updateConflicts() {
        conflicts = conflictDetector.conflicts(in: calendarBlocks)
    }

    private func mergeCalendarBlocks(_ fetched: [CalendarBlock], from start: Date, to end: Date) {
        let existing = calendarBlocks
        var protectedByID: [String: String] = [:]
        var protectedByFingerprint: [String: String] = [:]
        for block in existing {
            guard let reason = block.protectionReason else { continue }
            protectedByID[block.id] = reason
            protectedByFingerprint[calendarFingerprint(block)] = reason
        }

        let imported = fetched.map { block -> CalendarBlock in
            var block = block
            block.protectionReason = protectedByID[block.id] ?? protectedByFingerprint[calendarFingerprint(block)]
            return block
        }
        let local = existing.filter {
            $0.source == .nori && $0.end >= start && $0.start <= end
        }

        var unique: [String: CalendarBlock] = [:]
        for block in imported + local {
            let key = calendarFingerprint(block)
            if unique[key] == nil || block.source == .system {
                unique[key] = block
            }
        }
        calendarBlocks = unique.values.sorted { $0.start < $1.start }
    }

    private func calendarFingerprint(_ block: CalendarBlock) -> String {
        let minute = Int(block.start.timeIntervalSince1970 / 60)
        return "\(block.title.lowercased())|\(minute)|\(block.durationMinutes)"
    }

    private func observeCalendarChanges() {
        calendarChangeSubscription = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.refreshSchedule() }
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
