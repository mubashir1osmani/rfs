import BackgroundTasks
import Foundation
import UserNotifications

struct ConflictDetector {
    func conflicts(in blocks: [CalendarBlock]) -> [ScheduleConflict] {
        let protectedBlocks = blocks.filter(\.isProtected)
        var conflicts: [ScheduleConflict] = []

        for protectedBlock in protectedBlocks where protectedBlock.end >= Date() {
            for candidate in blocks where candidate.id != protectedBlock.id {
                if candidate.isProtected, candidate.id < protectedBlock.id { continue }
                if isDuplicate(protectedBlock, candidate) { continue }

                if protectedBlock.overlaps(candidate) {
                    conflicts.append(ScheduleConflict(
                        protectedBlock: protectedBlock,
                        conflictingBlock: candidate,
                        kind: .overlap
                    ))
                } else if transitionGap(between: protectedBlock, and: candidate) < 15 * 60 {
                    conflicts.append(ScheduleConflict(
                        protectedBlock: protectedBlock,
                        conflictingBlock: candidate,
                        kind: .tightTransition
                    ))
                }
            }
        }

        return conflicts.sorted {
            if $0.protectedBlock.start == $1.protectedBlock.start {
                return $0.kind == .overlap && $1.kind != .overlap
            }
            return $0.protectedBlock.start < $1.protectedBlock.start
        }
    }

    private func transitionGap(between first: CalendarBlock, and second: CalendarBlock) -> TimeInterval {
        if first.end <= second.start { return second.start.timeIntervalSince(first.end) }
        if second.end <= first.start { return first.start.timeIntervalSince(second.end) }
        return 0
    }

    private func isDuplicate(_ first: CalendarBlock, _ second: CalendarBlock) -> Bool {
        first.title.localizedCaseInsensitiveCompare(second.title) == .orderedSame
            && abs(first.start.timeIntervalSince(second.start)) < 60
            && abs(first.end.timeIntervalSince(second.end)) < 60
    }
}

@MainActor
final class ProactiveNotificationService {
    static let backgroundRefreshIdentifier = "com.nori.assistant.schedule-refresh"

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let notifiedConflictsKey = "notified-schedule-conflict-ids"

    func enable(protectedBlocks: [CalendarBlock], conflicts: [ScheduleConflict]) async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else { return }
        configureCategories()
        try await scheduleDailyNudge(protectedBlocks: protectedBlocks, conflicts: conflicts)
        await notifyNewConflicts(conflicts)
        scheduleBackgroundRefresh()
    }

    func sync(protectedBlocks: [CalendarBlock], conflicts: [ScheduleConflict]) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        try? await scheduleDailyNudge(protectedBlocks: protectedBlocks, conflicts: conflicts)
        await notifyNewConflicts(conflicts)
        scheduleBackgroundRefresh()
    }

    func disable() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter {
            $0 == "nori-daily-nudge" || $0.hasPrefix("nori-conflict-")
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundRefreshIdentifier)
        defaults.removeObject(forKey: notifiedConflictsKey)
    }

    private func notifyNewConflicts(_ conflicts: [ScheduleConflict]) async {
        let currentIDs = Set(conflicts.map(\.id))
        let previousIDs = Set(defaults.stringArray(forKey: notifiedConflictsKey) ?? [])
        let resolvedIdentifiers = previousIDs.subtracting(currentIDs).map { "nori-conflict-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: resolvedIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: resolvedIdentifiers)

        for conflict in conflicts where !previousIDs.contains(conflict.id) {
            let content = UNMutableNotificationContent()
            content.title = "Protected time needs a decision"
            content.body = conflict.summary
            content.sound = .default
            content.categoryIdentifier = "NORI_SCHEDULE_CONFLICT"
            content.userInfo = ["conflictID": conflict.id]
            let request = UNNotificationRequest(
                identifier: "nori-conflict-\(conflict.id)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            )
            try? await center.add(request)
        }

        defaults.set(Array(currentIDs), forKey: notifiedConflictsKey)
    }

    private func scheduleDailyNudge(
        protectedBlocks: [CalendarBlock],
        conflicts: [ScheduleConflict]
    ) async throws {
        center.removePendingNotificationRequests(withIdentifiers: ["nori-daily-nudge"])
        let todayCount = protectedBlocks.filter { Calendar.current.isDateInToday($0.start) }.count
        let decisionCount = conflicts.filter { Calendar.current.isDateInToday($0.protectedBlock.start) }.count
        let content = UNMutableNotificationContent()
        content.title = "Your protected time today"
        if todayCount == 0 {
            content.body = "Nothing is protected yet. Open Nori to reserve what matters."
        } else if decisionCount > 0 {
            content.body = "You have \(todayCount) protected block\(todayCount == 1 ? "" : "s") and \(decisionCount) conflict\(decisionCount == 1 ? "" : "s") needing a decision."
        } else {
            content.body = "You have \(todayCount) protected block\(todayCount == 1 ? "" : "s") today, and they are clear right now."
        }
        content.sound = .default
        content.categoryIdentifier = "NORI_DAILY_NUDGE"
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 7, minute: 30),
            repeats: true
        )
        try await center.add(UNNotificationRequest(
            identifier: "nori-daily-nudge",
            content: content,
            trigger: trigger
        ))
    }

    private func configureCategories() {
        let review = UNNotificationAction(
            identifier: "REVIEW_CONFLICT",
            title: "Review",
            options: [.foreground]
        )
        let conflict = UNNotificationCategory(
            identifier: "NORI_SCHEDULE_CONFLICT",
            actions: [review],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([conflict])
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
