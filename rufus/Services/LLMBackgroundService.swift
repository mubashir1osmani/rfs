//
//  LLMBackgroundService.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-11.
//

import Foundation
import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications

class LLMBackgroundService: ObservableObject {
    static let shared = LLMBackgroundService()
    
    private let groqService = GroqService.shared
    private let notificationService = NotificationService.shared
    private let backgroundTaskHandler = BackgroundTaskHandler.shared
    
    @AppStorage("dailyBriefingEnabled") private var dailyBriefingEnabled: Bool = false
    @AppStorage("dailyBriefingTime") private var dailyBriefingTime: Double = 9.0 // 9:00 AM default
    
    // Track if we've scheduled tasks since app launch
    private var hasScheduledTasks = false
    
    func setupBackgroundTasks() {
        // Schedule the daily briefing if enabled
        if dailyBriefingEnabled && !hasScheduledTasks {
            scheduleDailyBriefing()
            hasScheduledTasks = true
        }
    }
    
    func scheduleDailyBriefing() {
        guard dailyBriefingEnabled else { return }
        
        // Calculate time components
        let hour = Int(dailyBriefingTime)
        let minute = Int((dailyBriefingTime.truncatingRemainder(dividingBy: 1)) * 60)
        
        // Create date components for the desired time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Schedule the notification for the next occurrence of this time
        notificationService.scheduleDailyNotification(
            title: "Daily Briefing",
            body: "Your daily briefing is ready to view",
            identifier: "daily-briefing",
            at: dateComponents,
            repeats: true
        )
        
        print("Scheduled daily briefing for \(hour):\(minute)")
    }
    
    func refreshBackgroundSchedule() {
        // Cancel existing notifications
        notificationService.cancelNotification(withIdentifier: "daily-briefing")
        
        // Reschedule if needed
        if dailyBriefingEnabled {
            scheduleDailyBriefing()
        }
    }
    
    // Used by the background task to generate the briefing content
    func generateBriefingInBackground(modelContext: ModelContext) async -> String? {
        // Get current date outside of the predicate
        let currentDate = Date()
        
        // Get assignments from SwiftData
        let assignmentDescriptor = FetchDescriptor<Assignment>(
            predicate: #Predicate<Assignment> {
                $0.isCompleted == false && $0.dueDate > currentDate
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        
        // Get courses from SwiftData
        let coursesDescriptor = FetchDescriptor<Course>()
        
        do {
            let assignments = try modelContext.fetch(assignmentDescriptor)
            let courses = try modelContext.fetch(coursesDescriptor)
            
            // Get calendar events for the next 7 days
            let calendarService = await CalendarService.shared
            let now = Date()
            let calendar = Calendar.current
            guard let endDate = calendar.date(byAdding: .day, value: 7, to: now) else {
                return nil
            }
            
            let events = try await calendarService.loadAllCalendarEvents(from: now, to: endDate)
            
            // Generate the briefing with all the context
            return try await groqService.generateDailyBriefing(
                assignments: assignments,
                events: events,
                courses: courses
            )
        } catch {
            print("Error generating briefing in background: \(error.localizedDescription)")
            return nil
        }
    }
}
