//
//  CalendarService.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-10.
//

import Foundation
import EventKit
import GoogleSignIn

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let url: URL?
    let isAllDay: Bool
    let source: CalendarSource
}

enum CalendarSource: String, CaseIterable {
    case apple = "Apple Calendar"
    case google = "Google Calendar"
    
    var displayName: String {
        return self.rawValue
    }
}

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    @Published private(set) var calendarEvents: [CalendarEvent] = []
    @Published private(set) var hasCalendarAccess = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let eventStore = EKEventStore()
    private let googleCalendarService = GoogleCalendarService()

    private init() {
        Task {
            await ensureEventAccess()
            await loadUpcomingEvents()
        }
    }

    // MARK: - Public API
    func checkCalendarAccess() {
        Task {
            await ensureEventAccess()
        }
    }

    func ensureEventAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            hasCalendarAccess = true
        case .restricted, .denied:
            hasCalendarAccess = false
            errorMessage = "Calendar access denied. Please enable in Settings."
        case .notDetermined, .writeOnly:
            await requestCalendarPermission()
        @unknown default:
            hasCalendarAccess = false
            errorMessage = "Unknown calendar permission status."
        }
    }

    func requestCalendarPermission() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }

            await MainActor.run {
                hasCalendarAccess = granted
                if !granted {
                    errorMessage = "Calendar access was denied."
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to request calendar permission: \(error.localizedDescription)"
            }
        }
    }

    func loadUpcomingEvents(range: DateInterval? = nil) async {
        guard !isLoading else { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let now = Date()
        let interval = range ?? DateInterval(start: Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now,
                                             end: Calendar.current.date(byAdding: .month, value: 2, to: now) ?? now)

        async let appleEvents = fetchAppleEvents(in: interval)
        async let googleEvents = fetchGoogleEvents(in: interval)

        do {
            let combined = try await appleEvents + googleEvents
            await MainActor.run {
                self.calendarEvents = combined.sorted { $0.startDate < $1.startDate }
                self.lastUpdated = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func refreshAllCalendars() {
        Task {
            await ensureEventAccess()
            await loadUpcomingEvents()
        }
    }

    func loadAllCalendarEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        let interval = DateInterval(start: startDate, end: endDate)
        async let apple = fetchAppleEvents(in: interval)
        async let google = fetchGoogleEvents(in: interval)
        let combined = try await apple + google
        await MainActor.run { lastUpdated = Date() }
        return combined
    }

    func createEvent(title: String, startDate: Date, endDate: Date, isAllDay: Bool = false) {
        guard hasCalendarAccess else {
            errorMessage = "Calendar access is required to create events."
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            Task { await loadUpcomingEvents() }
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
        }
    }

    var lastSyncDescription: String {
        guard let lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }

    // MARK: - Private helpers
    private func fetchAppleEvents(in interval: DateInterval) async throws -> [CalendarEvent] {
        guard hasCalendarAccess else { return [] }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        return eventStore.events(matching: predicate).map { event in
            CalendarEvent(
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                url: event.url,
                isAllDay: event.isAllDay,
                source: .apple
            )
        }
    }

    private func fetchGoogleEvents(in interval: DateInterval) async throws -> [CalendarEvent] {
        guard GIDSignIn.sharedInstance.currentUser != nil else { return [] }

        let events = try await googleCalendarService.fetchGoogleCalendarEvents(from: interval.start, to: interval.end)
        return events.compactMap { eventDict -> CalendarEvent? in
            guard let summary = eventDict["summary"] as? String else { return nil }

            let startInfo = eventDict["start"] as? [String: Any]
            let endInfo = eventDict["end"] as? [String: Any]

            let (startDate, isAllDay) = parseDateComponents(from: startInfo)
            let (endDate, _) = parseDateComponents(from: endInfo, defaultDate: startDate)

            return CalendarEvent(
                title: summary,
                startDate: startDate,
                endDate: endDate,
                location: eventDict["location"] as? String,
                notes: eventDict["description"] as? String,
                url: nil,
                isAllDay: isAllDay,
                source: .google
            )
        }
    }

    private func parseDateComponents(from dictionary: [String: Any]?, defaultDate: Date = Date()) -> (Date, Bool) {
        if let dateTime = dictionary?["dateTime"] as? String,
           let parsed = ISO8601DateFormatter().date(from: dateTime) {
            return (parsed, false)
        }

        if let dateString = dictionary?["date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                return (date, true)
            }
        }

        return (defaultDate, false)
    }
}

// MARK: - UIColor Extension
extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "#%02X%02X%02X",
                     Int(red * 255),
                     Int(green * 255),
                     Int(blue * 255))
    }
}
