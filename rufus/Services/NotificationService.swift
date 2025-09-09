//
//  NotificationService.swift
//  rufus
//
//  Created by AI Assistant on 2025-07-25.
//

import Foundation
import SwiftData
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    func scheduleDailyNotification(title: String, body: String, identifier: String, at dateComponents: DateComponents, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Create a calendar trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        
        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily notification: \(error)")
            } else {
                print("Daily notification scheduled successfully: \(identifier)")
            }
        }
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Notification canceled: \(identifier)")
    }
    
    func requestPermission() async -> Bool {
        let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authorizationOptions)
            return granted
        } catch {
            print("Error requesting notification permissions: \(error)")
            return false
        }
    }
    
    func scheduleAssignmentReminder(for assignment: Assignment) {
        let content = UNMutableNotificationContent()
        content.title = "Assignment Reminder: \(assignment.title)"
        content.body = generateAnnoyingMessage(for: assignment)
        content.sound = .default
        content.badge = 1
        
        // Schedule multiple notifications to be extra annoying
        scheduleAnnoyingNotifications(for: assignment, content: content)
    }
    
    private func scheduleAnnoyingNotifications(for assignment: Assignment, content: UNMutableNotificationContent) {
        let center = UNUserNotificationCenter.current()
        
        // Main reminder
        if assignment.reminderDate.timeIntervalSinceNow > 0 {
            let mainReminder = UNTimeIntervalNotificationTrigger(timeInterval: assignment.reminderDate.timeIntervalSinceNow, repeats: false)
            let mainRequest = UNNotificationRequest(identifier: "assignment_\(assignment.id)_main", content: content, trigger: mainReminder)
            
            center.add(mainRequest) { error in
                if let error = error {
                    print("Error scheduling main notification: \(error)")
                }
            }
        }
        
        // An extra annoying reminder 30 minutes after main reminder
        let annoyingReminderTime = assignment.reminderDate.addingTimeInterval(1800) // 30 minutes after
        if annoyingReminderTime.timeIntervalSinceNow > 0 {
            let annoyingContent = UNMutableNotificationContent()
            annoyingContent.title = "🚨 STILL NEED TO DO THIS! 🚨"
            annoyingContent.body = "I know you're ignoring me, but you really need to work on \(assignment.title)!"
            annoyingContent.sound = .default
            annoyingContent.badge = 1
            
            let annoyingTrigger = UNTimeIntervalNotificationTrigger(timeInterval: annoyingReminderTime.timeIntervalSinceNow, repeats: false)
            let annoyingRequest = UNNotificationRequest(identifier: "assignment_\(assignment.id)_annoying1", content: annoyingContent, trigger: annoyingTrigger)
            
            center.add(annoyingRequest) { error in
                if let error = error {
                    print("Error scheduling annoying notification 1: \(error)")
                }
            }
        }
        
        // Even more annoying reminder 1 hour before due date if it's different from reminder
        let hourBeforeDue = assignment.dueDate.addingTimeInterval(-3600)
        if hourBeforeDue > assignment.reminderDate && hourBeforeDue.timeIntervalSinceNow > 0 {
            let urgentContent = UNMutableNotificationContent()
            urgentContent.title = "⚠️ ULTIMATE WARNING ⚠️"
            urgentContent.body = "This is your FINAL reminder for \(assignment.title)! It's due in 1 hour!"
            urgentContent.sound = .defaultCritical
            urgentContent.badge = 1
            
            let urgentTrigger = UNTimeIntervalNotificationTrigger(timeInterval: hourBeforeDue.timeIntervalSinceNow, repeats: false)
            let urgentRequest = UNNotificationRequest(identifier: "assignment_\(assignment.id)_urgent", content: urgentContent, trigger: urgentTrigger)
            
            center.add(urgentRequest) { error in
                if let error = error {
                    print("Error scheduling urgent notification: \(error)")
                }
            }
        }
        
        // Extremely annoying reminder 10 minutes before due date
        let tenMinutesBeforeDue = assignment.dueDate.addingTimeInterval(-600)
        if tenMinutesBeforeDue > assignment.reminderDate && tenMinutesBeforeDue.timeIntervalSinceNow > 0 {
            let extremeContent = UNMutableNotificationContent()
            extremeContent.title = "💥 LAST CALL BEFORE LATE! 💥"
            extremeContent.body = "You have 10 MINUTES to finish \(assignment.title) before it's LATE!"
            extremeContent.sound = .defaultCritical
            extremeContent.badge = 1
            
            let extremeTrigger = UNTimeIntervalNotificationTrigger(timeInterval: tenMinutesBeforeDue.timeIntervalSinceNow, repeats: false)
            let extremeRequest = UNNotificationRequest(identifier: "assignment_\(assignment.id)_extreme", content: extremeContent, trigger: extremeTrigger)
            
            center.add(extremeRequest) { error in
                if let error = error {
                    print("Error scheduling extreme notification: \(error)")
                }
            }
        }
    }
    
    private func generateAnnoyingMessage(for assignment: Assignment) -> String {
        let messages = [
            "Hey lazy bones! Don't forget about \(assignment.title)! Get working!",
            "Psst... \(assignment.title) isn't going to do itself. Start now!",
            "Stop procrastinating! \(assignment.title) needs your attention RIGHT NOW!",
            "I hate to interrupt your social media browsing, but \(assignment.title) won't complete itself!",
            "You promised yourself you'd be productive today. Time to work on \(assignment.title)!",
            "Your future self will thank you for working on \(assignment.title) now!",
            "BREAKING NEWS: \(assignment.title) still needs to be done. This is your brain on assignments.",
            "Achievement unlocked: Procrastination Expert. Now unlock 'Actually Getting Things Done' with \(assignment.title)!",
            "Your professor is waiting for \(assignment.title). Don't make them wait forever!",
            "Time is ticking! \(assignment.title) deadline approaching fast!",
            "Don't be that student who submits \(assignment.title) late. Start now!",
            "The clock is ticking on \(assignment.title). Can you hear it?",
            "I'm not angry, just disappointed that you haven't started \(assignment.title) yet.",
            "Every second you delay \(assignment.title) is a second you'll regret later!"
        ]
        
        return messages.randomElement() ?? "Work on \(assignment.title) now!"
    }
    
    func cancelNotifications(for assignmentId: UUID) {
        let identifiers = [
            "assignment_\(assignmentId)_main",
            "assignment_\(assignmentId)_annoying1",
            "assignment_\(assignmentId)_urgent",
            "assignment_\(assignmentId)_extreme"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func generateNotificationForAssignment(_ assignment: Assignment) -> NotificationItem {
        let message = generateAnnoyingMessage(for: assignment)
        return NotificationItem(
            title: "Assignment Reminder: \(assignment.title)",
            message: message,
            assignmentId: assignment.id
        )
    }
}
