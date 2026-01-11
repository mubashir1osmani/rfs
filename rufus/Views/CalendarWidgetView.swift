//
//  CalendarWidgetView.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-10.
//

import SwiftUI
import GoogleSignIn

struct CalendarWidgetView: View {
    @Binding var selectedDate: Date
    let assignments: [Assignment]
    @ObservedObject private var calendarService = CalendarService.shared
    @State private var showingEventDetail: CalendarEvent?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Calendar")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    calendarService.refreshAllCalendars()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .disabled(calendarService.isLoading)
            }
            
            // Calendar Source Status
            HStack {
                if calendarService.hasCalendarAccess {
                    Label("Apple Calendar", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Button("Connect Apple Calendar") {
                        calendarService.checkCalendarAccess()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                if GIDSignIn.sharedInstance.currentUser != nil {
                    Label("Google Calendar", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Button("Connect Google Calendar") {
                        // Google sign-in is handled in AuthView
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                }
            }
            
            // Loading indicator
            if calendarService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading events...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Compact calendar - show only current week
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekDays(), id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        hasAssignment: hasAssignmentOnDate(date),
                        hasEvent: hasEventOnDate(date),
                        onTap: { selectedDate = date }
                    )
                }
            }
            
            // Events for selected date
            if !eventsForSelectedDate().isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Events for \(formatDate(selectedDate))")
                        .font(.headline)
                        .padding(.top)
                    
                    ForEach(eventsForSelectedDate(), id: \.id) { event in
                        EventRowView(event: event) {
                            showingEventDetail = event
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(item: $showingEventDetail) { event in
            EventDetailView(event: event)
        }
        .onAppear {
            calendarService.checkCalendarAccess()
        }
    }
    
    // Helper functions
    private func weekDays() -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    private func hasAssignmentOnDate(_ date: Date) -> Bool {
        assignments.contains { assignment in
            Calendar.current.isDate(assignment.dueDate, inSameDayAs: date)
        }
    }
    
    private func hasEventOnDate(_ date: Date) -> Bool {
        calendarService.calendarEvents.contains { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: date)
        }
    }
    
    private func eventsForSelectedDate() -> [CalendarEvent] {
        calendarService.calendarEvents.filter { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: selectedDate)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasAssignment: Bool
    let hasEvent: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
            
            HStack(spacing: 2) {
                if hasAssignment {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4, height: 4)
                }
                if hasEvent {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(width: 40, height: 40)
        .background(isSelected ? Color.blue : Color.clear)
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

struct EventRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Source indicator
            Rectangle()
                .fill(event.source == .apple ? Color.blue : Color.green)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(timeString(from: event.startDate, to: event.endDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let location = event.location {
                        Text("• \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
    
    private func timeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}

struct EventDetailView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(event.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Time and date
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text(timeAndDateString())
                        } icon: {
                            Image(systemName: "clock")
                        }
                        
                        if let location = event.location {
                            Label {
                                Text(location)
                            } icon: {
                                Image(systemName: "location")
                            }
                        }
                        
                        Label {
                            Text(event.source.displayName)
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .foregroundColor(event.source == .apple ? .blue : .green)
                    }
                    
                    // Notes
                    if let notes = event.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            
                            Text(notes)
                                .font(.body)
                        }
                    }
                    
                    // Open in calendar app
                    if let url = event.url {
                        Button(action: {
                            UIApplication.shared.open(url)
                        }) {
                            Label("Open in Calendar", systemImage: "calendar")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func timeAndDateString() -> String {
        let formatter = DateFormatter()
        
        if event.isAllDay {
            formatter.dateStyle = .full
            return formatter.string(from: event.startDate)
        } else {
            if Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
                formatter.dateStyle = .full
                let dateString = formatter.string(from: event.startDate)
                
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                let startTime = formatter.string(from: event.startDate)
                let endTime = formatter.string(from: event.endDate)
                
                return "\(dateString)\n\(startTime) - \(endTime)"
            } else {
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
            }
        }
    }
}
