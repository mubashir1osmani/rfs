//
//  AssignmentRowView.swift
//  rufus
//
//  Created by AI Assistant on 2025-07-25.
//

import SwiftUI
import SwiftData

struct AssignmentRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var assignment: Assignment
    @AppStorage("llmEnabled") private var llmEnabled: Bool = false
    @AppStorage("smartRemindersEnabled") private var smartRemindersEnabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Course color indicator
                if let course = assignment.course {
                    Circle()
                        .fill(Color(hex: course.color))
                        .frame(width: 8, height: 8)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.title)
                        .font(.headline)
                    
                    // Show course name if available, otherwise show subject
                    if let course = assignment.course {
                        Text(course.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if !assignment.subject.isEmpty {
                        Text(assignment.subject)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Due: \(assignment.dueDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(assignment.isOverdue ? .red : .secondary)
                }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                priorityIndicator
                Toggle("", isOn: $assignment.isCompleted)
                    .labelsHidden()
            }
            
            // End of HStack
        }
        
        // Add Smart Reminder if enabled
        if llmEnabled && smartRemindersEnabled && !assignment.isCompleted {
            SmartReminderView(assignment: assignment)
                .padding(.leading, 16)
                .padding(.top, 4)
        }
        
        // End of VStack
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Delete", role: .destructive) {
                deleteAssignment()
            }
        }
    }
    
    private var priorityIndicator: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 12, height: 12)
    }
    
    private var priorityColor: Color {
        switch assignment.priority {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private func deleteAssignment() {
        // Cancel any scheduled notifications for this assignment
        NotificationService.shared.cancelNotifications(for: assignment.id)
        
        // Delete the assignment
        modelContext.delete(assignment)
    }
}

extension Assignment {
    var isOverdue: Bool {
        return !isCompleted && dueDate < Date()
    }
}

#Preview {
    AssignmentRowView(assignment: Assignment(
        title: "Math Homework",
        assignmentDescription: "Complete exercises 1-20",
        dueDate: Date().addingTimeInterval(86400),
        reminderDate: Date().addingTimeInterval(43200),
        subject: "Mathematics",
        priority: .high
    ))
    .modelContainer(for: Assignment.self, inMemory: true)
}
