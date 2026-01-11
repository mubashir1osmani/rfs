//
//  GoalDetailView.swift
//  rufus
//
//  Detailed goal view with task management
//

import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: Goal

    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    @State private var editMode = false

    var sortedTasks: [GoalTask] {
        goal.tasks.sorted { $0.order < $1.order }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header card
                    headerCard

                    // Progress section
                    progressSection

                    // Tasks section
                    tasksSection
                }
                .padding()
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode ? "Done" : "Edit") {
                        editMode.toggle()
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(goal: goal)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: goal.icon)
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: goal.color))

                Spacer()

                if goal.isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            if editMode {
                TextField("Goal Title", text: $goal.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text(goal.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            if editMode {
                TextEditor(text: $goal.goalDescription)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Label(goal.category.rawValue, systemImage: goal.category.icon)
                    .font(.caption)
                    .foregroundColor(Color(hex: goal.category.color))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: goal.category.color).opacity(0.1))
                    .cornerRadius(8)

                if editMode {
                    Picker("Status", selection: $goal.status) {
                        ForEach(GoalStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                } else {
                    Label(goal.status.rawValue, systemImage: goal.status.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }

            if let deadline = goal.deadline {
                HStack {
                    Image(systemName: "calendar")
                    Text("Due \(deadline, style: .date)")
                        .font(.subheadline)
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color(hex: goal.color))

                    Text("\(goal.tasks.filter { $0.completed }.count) of \(goal.tasks.count) tasks completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                CircularProgressView(progress: goal.progress, color: Color(hex: goal.color))
                    .frame(width: 80, height: 80)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(.headline)

                Spacer()

                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                }
            }

            if goal.tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))

                    Text("No tasks yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Button(action: { showingAddTask = true }) {
                        Text("Add First Task")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(sortedTasks) { task in
                    GoalTaskRow(task: task, goal: goal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Goal Task Row

struct GoalTaskRow: View {
    @Bindable var task: GoalTask
    let goal: Goal
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { toggleCompletion() }) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.completed ? .green : .gray)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.completed)
                    .foregroundColor(task.completed ? .secondary : .primary)

                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let dueDate = task.dueDate {
                    Text("Due \(dueDate, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Button(action: { deleteTask() }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func toggleCompletion() {
        withAnimation {
            task.completed.toggle()
            goal.updateProgress()
        }
    }

    private func deleteTask() {
        withAnimation {
            modelContext.delete(task)
            goal.updateProgress()
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - Add Task View

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: Goal

    @State private var title = ""
    @State private var taskDescription = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                        .font(.headline)

                    TextField("Description (optional)", text: $taskDescription)
                        .font(.subheadline)
                }

                Section(header: Text("Due Date")) {
                    Toggle("Set Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveTask() {
        let task = GoalTask(
            title: title,
            taskDescription: taskDescription,
            dueDate: hasDueDate ? dueDate : nil,
            order: goal.tasks.count,
            goal: goal
        )

        modelContext.insert(task)
        goal.updateProgress()
        dismiss()
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Goal.self, GoalTask.self, configurations: config)

        let goal = Goal(title: "Learn SwiftUI", goalDescription: "Master SwiftUI development")
        container.mainContext.insert(goal)

        return GoalDetailView(goal: goal)
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
