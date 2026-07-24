import AppIntents
import Foundation

struct CheckProtectedTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Protected Time"
    static var description = IntentDescription("Summarizes the time Nori is protecting today.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = try await AppStateStore().load()
        let blocks = (state?.calendarBlocks ?? [])
            .filter { $0.isProtected && Calendar.current.isDateInToday($0.start) }
            .sorted { $0.start < $1.start }

        guard !blocks.isEmpty else {
            return .result(dialog: "You do not have any protected time today.")
        }
        let summary = blocks.map {
            "\($0.title) at \($0.start.formatted(date: .omitted, time: .shortened))"
        }.joined(separator: ", ")
        return .result(dialog: "You have \(blocks.count) protected block\(blocks.count == 1 ? "" : "s"): \(summary).")
    }
}

struct ProtectNextBlockIntent: AppIntent {
    static var title: LocalizedStringResource = "Protect My Next Block"
    static var description = IntentDescription("Marks the next calendar block as protected in Nori.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = AppStateStore()
        guard let state = try await store.load(),
              let index = state.calendarBlocks.indices
                .filter({ state.calendarBlocks[$0].end > Date() })
                .min(by: { state.calendarBlocks[$0].start < state.calendarBlocks[$1].start }) else {
            return .result(dialog: "There is no upcoming calendar block to protect.")
        }

        var blocks = state.calendarBlocks
        blocks[index].protectionReason = "Protected with Siri"
        let updated = PersistedAppState(
            tasks: state.tasks,
            calendarBlocks: blocks,
            messages: state.messages,
            actionStates: state.actionStates,
            autonomyEnabled: state.autonomyEnabled,
            proactiveAlertsEnabled: state.proactiveAlertsEnabled
        )
        try await store.save(updated, revision: UInt64(Date().timeIntervalSince1970 * 1_000))
        return .result(dialog: "\(blocks[index].title) is now protected.")
    }
}

struct NoriAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckProtectedTimeIntent(),
            phrases: [
                "What's protected in \(.applicationName)",
                "Check my protected time with \(.applicationName)",
            ],
            shortTitle: "Check Protected Time",
            systemImageName: "shield.checkered"
        )
        AppShortcut(
            intent: ProtectNextBlockIntent(),
            phrases: [
                "Protect my next block with \(.applicationName)",
                "Make my next block sacred in \(.applicationName)",
            ],
            shortTitle: "Protect Next Block",
            systemImageName: "shield.fill"
        )
    }
}
