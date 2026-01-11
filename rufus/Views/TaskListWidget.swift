//
//  TaskListWidget.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-10.
//

import SwiftUI
import SwiftData

struct TaskListWidget: View {
    let title: String
    let assignments: [Assignment]
    @Binding var showingAddAssignment: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingAddAssignment = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }

            if assignments.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No active tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Add a task") {
                        showingAddAssignment = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else {
                // Tasks list
                VStack(spacing: 8) {
                    ForEach(assignments.prefix(3)) { assignment in
                        TaskRow(assignment: assignment)
                    }

                    if assignments.count > 3 {
                        Text("+\(assignments.count - 3) more tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }
}

struct TaskRow: View {
    @Bindable var assignment: Assignment

    var body: some View {
        HStack(spacing: 12) {
            // Completion checkbox
            Button(action: {
                assignment.isCompleted.toggle()
            }) {
                Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(assignment.isCompleted ? .green : .secondary)
                    .font(.title3)
            }

            // Course color indicator
            if let course = assignment.course {
                Circle()
                    .fill(Color(hex: course.color))
                    .frame(width: 6, height: 6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(assignment.isCompleted)
                    .foregroundColor(assignment.isCompleted ? .secondary : .primary)

                if let course = assignment.course {
                    Text(course.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Due: \(assignment.dueDate, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(assignment.isOverdue ? .red : .secondary)
            }

            Spacer()

            // Priority indicator
            if assignment.priority > .medium {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

#Preview {
    TaskListWidget(
        title: "Active Tasks",
        assignments: [],
        showingAddAssignment: .constant(false)
    )
    .padding()
}