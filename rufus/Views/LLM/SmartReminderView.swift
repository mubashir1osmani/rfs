//
//  SmartReminderView.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-11.
//

import SwiftUI
import SwiftData

struct SmartReminderView: View {
    let assignment: Assignment
    @State private var reminderText: String = ""
    @State private var isLoading: Bool = true
    @State private var loadingError: Bool = false
    
    @Query private var courses: [Course]
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("smartRemindersEnabled") private var smartRemindersEnabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if smartRemindersEnabled {
                if isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 20, height: 20)
                        Text("Generating smart reminder...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if loadingError {
                    Text("Could not generate a smart reminder")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if !reminderText.isEmpty {
                    HStack(alignment: .top) {
                        Image(systemName: "brain")
                            .foregroundColor(.purple)
                            .padding(.top, 2)
                        
                        Text(reminderText)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.1))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if smartRemindersEnabled {
                loadSmartReminder()
            } else {
                isLoading = false
            }
        }
        .onChange(of: smartRemindersEnabled) { newValue, _ in
            if newValue && reminderText.isEmpty {
                isLoading = true
                loadSmartReminder()
            }
        }
    }
    
    private func loadSmartReminder() {
        guard smartRemindersEnabled else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let reminder = try await GroqService.shared.generateSmartReminder(
                    for: assignment,
                    with: "Context about the assignment"
                )
                
                await MainActor.run {
                    self.reminderText = reminder
                    self.isLoading = false
                }
            } catch {
                print("Failed to generate smart reminder: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadingError = true
                    self.isLoading = false
                }
            }
        }
    }
}

struct DailyBriefingView: View {
    @Query private var assignments: [Assignment]
    @Query private var courses: [Course]
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("dailyBriefingEnabled") private var dailyBriefingEnabled: Bool = false
    
    @State private var briefingText: String = ""
    @State private var isLoading: Bool = true
    @State private var loadingError: Bool = false
    @State private var calendarEvents: [CalendarEvent] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Briefing")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isLoading = true
                    loadDailyBriefing()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
            }
            
            if dailyBriefingEnabled {
                if isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Generating your daily briefing...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                } else if loadingError {
                    Text("Could not generate your daily briefing. Please try again later.")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                } else if !briefingText.isEmpty {
                    ScrollView {
                        Text(briefingText)
                            .font(.body)
                            .padding()
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .frame(height: 200)
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("Enable daily briefings in LLM settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            if dailyBriefingEnabled {
                Task {
                    await loadCalendarEvents()
                    loadDailyBriefing()
                }
            } else {
                isLoading = false
            }
        }
        .onChange(of: dailyBriefingEnabled) { newValue, _ in
            if newValue {
                isLoading = true
                Task {
                    await loadCalendarEvents()
                    loadDailyBriefing()
                }
            }
        }
    }
    
    private func loadDailyBriefing() {
        guard dailyBriefingEnabled else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let briefing = try await GroqService.shared.generateDailyBriefing(
                    assignments: assignments,
                    events: calendarEvents,
                    courses: courses
                )
                
                await MainActor.run {
                    self.briefingText = briefing
                    self.isLoading = false
                }
            } catch {
                print("Failed to generate daily briefing: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadCalendarEvents() async {
        let calendarService = CalendarService.shared
        
        // Get today's date range
        let now = Date()
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now),
              let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now) else { 
            return
        }
        
        do {
            // First get today's events
            let todayEvents = try await calendarService.loadAllCalendarEvents(from: startOfDay, to: endOfDay)
            
            // Then get upcoming week events
            let upcomingEvents = try await calendarService.loadAllCalendarEvents(from: now, to: endOfWeek)
            
            // Combine them with priority to today's events
            await MainActor.run {
                self.calendarEvents = todayEvents + upcomingEvents.filter { event in
                    // Remove duplicates
                    !todayEvents.contains { $0.id == event.id }
                }
            }
        } catch {
            print("Failed to load calendar events: \(error.localizedDescription)")
            // Continue even if we can't load calendar events
        }
    }
}

#Preview {
    VStack {
        Text("Smart Reminder Preview")
            .font(.headline)
        
        SmartReminderView(assignment: Assignment(
            title: "Final Project",
            assignmentDescription: "Complete the term paper on machine learning applications",
            dueDate: Date().addingTimeInterval(60 * 60 * 24 * 3), // 3 days from now
            reminderDate: Date().addingTimeInterval(60 * 60 * 24 * 2), // 2 days from now
            subject: "Computer Science",
            priority: .high
        ))
        .padding()
        
        Divider()
        
        DailyBriefingView()
    }
    .padding()
}
