import EventKit
import Foundation
import UIKit

enum IntegrationError: LocalizedError {
    case calendarAccessDenied
    case missingEmailRecipient
    case actionFailed

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied: "Allow Calendar access in Settings to add this event."
        case .missingEmailRecipient: "Add a recipient before sending this email."
        case .actionFailed: "Nori couldn’t complete that action. Please try again."
        }
    }
}

@MainActor
final class IntegrationService {
    private struct ExecutionRequest: Encodable {
        let action: AssistantAction
        let approved = true
    }

    private let configuration: AppConfiguration
    private let eventStore = EKEventStore()

    init(configuration: AppConfiguration = .current) {
        self.configuration = configuration
    }

    func execute(_ action: AssistantAction) async throws {
        if await executeRemotely(action) { return }
        switch action.kind {
        case .calendar, .meeting:
            try await addToSystemCalendar(action)
        case .email:
            try openMailDraft(action)
        case .task:
            return
        }
    }

    private func executeRemotely(_ action: AssistantAction) async -> Bool {
        guard let url = configuration.executeURL else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let appToken = configuration.appToken {
            request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONEncoder().encode(ExecutionRequest(action: action))
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 200
    }

    private func addToSystemCalendar(_ action: AssistantAction) async throws {
        let hasAccess = try await eventStore.requestFullAccessToEvents()
        guard hasAccess, let calendar = eventStore.defaultCalendarForNewEvents else {
            throw IntegrationError.calendarAccessDenied
        }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = action.title ?? (action.kind == .meeting ? "Meeting" : "Focus block")
        event.startDate = action.startDate
        event.endDate = action.startDate.addingTimeInterval(TimeInterval((action.durationMinutes ?? 60) * 60))
        event.notes = action.notes ?? "Planned with Nori"
        event.url = URL(string: "nori://action/\(action.id)")
        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    private func openMailDraft(_ action: AssistantAction) throws {
        guard let recipient = action.to, !recipient.isEmpty else {
            throw IntegrationError.missingEmailRecipient
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: action.subject ?? "Quick follow-up"),
            URLQueryItem(name: "body", value: action.body ?? ""),
        ]
        guard let url = components.url else { throw IntegrationError.actionFailed }
        UIApplication.shared.open(url)
    }
}
