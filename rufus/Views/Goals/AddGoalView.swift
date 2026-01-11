//
//  AddGoalView.swift
//  rufus
//
//  Add new goal
//

import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var goalDescription = ""
    @State private var selectedCategory: GoalCategory = .personal
    @State private var selectedPriority: Priority = .medium
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var isPrivate = true
    @State private var selectedColor = "#8B5CF6"
    @State private var selectedIcon = "target"

    let availableIcons = [
        "target", "star.fill", "flag.fill", "heart.fill",
        "bolt.fill", "sparkles", "trophy.fill", "flame.fill"
    ]

    let availableColors = [
        "#8B5CF6", "#3B82F6", "#10B981", "#F59E0B",
        "#EF4444", "#EC4899", "#8B5CF6", "#6B7280"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Goal Details")) {
                    TextField("Goal Title", text: $title)
                        .font(.headline)

                    TextEditor(text: $goalDescription)
                        .frame(minHeight: 80)
                        .overlay(
                            Group {
                                if goalDescription.isEmpty {
                                    Text("Describe your goal...")
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                            }
                        )
                }

                Section(header: Text("Category & Priority")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(GoalCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }

                    Picker("Priority", selection: $selectedPriority) {
                        ForEach([Priority.low, Priority.medium, Priority.high, Priority.critical], id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                }

                Section(header: Text("Deadline")) {
                    Toggle("Set Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Due Date", selection: $deadline, displayedComponents: [.date])
                    }
                }

                Section(header: Text("Customize Appearance")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableIcons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .foregroundColor(selectedIcon == icon ? .white : Color(hex: selectedColor))
                                            .frame(width: 50, height: 50)
                                            .background(selectedIcon == icon ? Color(hex: selectedColor) : Color(.systemGray6))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        Text("Color")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableColors, id: \.self) { color in
                                    Button(action: { selectedColor = color }) {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                            )
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Privacy")) {
                    Toggle(isOn: $isPrivate) {
                        Label("Private Goal", systemImage: "lock.fill")
                            .foregroundColor(.green)
                    }

                    Text("Private goals are stored locally and never synced to the cloud.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        saveGoal()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveGoal() {
        let goal = Goal(
            title: title,
            goalDescription: goalDescription,
            deadline: hasDeadline ? deadline : nil,
            priority: selectedPriority,
            category: selectedCategory,
            isPrivate: isPrivate,
            color: selectedColor,
            icon: selectedIcon
        )

        modelContext.insert(goal)
        dismiss()
    }
}

#Preview {
    AddGoalView()
        .modelContainer(for: [Goal.self])
}
