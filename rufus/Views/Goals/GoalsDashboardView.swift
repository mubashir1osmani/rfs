//
//  GoalsDashboardView.swift
//  rufus
//
//  Personal goals dashboard with privacy controls
//

import SwiftUI
import SwiftData

struct GoalsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.updatedDate, order: .reverse) private var allGoals: [Goal]

    @State private var selectedFilter: GoalStatus? = nil
    @State private var selectedCategory: GoalCategory? = nil
    @State private var showingAddSheet = false
    @State private var selectedGoal: Goal?
    @State private var searchText = ""

    var filteredGoals: [Goal] {
        var goals = allGoals

        if let status = selectedFilter {
            goals = goals.filter { $0.status == status }
        }

        if let category = selectedCategory {
            goals = goals.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            goals = goals.filter { goal in
                goal.title.localizedCaseInsensitiveContains(searchText) ||
                goal.goalDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        return goals
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats overview
                statsSection

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search goals...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedFilter == nil,
                            icon: "square.grid.2x2"
                        ) {
                            selectedFilter = nil
                        }

                        ForEach(GoalStatus.allCases, id: \.self) { status in
                            FilterChip(
                                title: status.rawValue,
                                isSelected: selectedFilter == status,
                                icon: status.icon
                            ) {
                                selectedFilter = status
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button(action: { selectedCategory = nil }) {
                            Text("All Categories")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == nil ? Color.purple : Color(.systemGray6))
                                .foregroundColor(selectedCategory == nil ? .white : .primary)
                                .cornerRadius(16)
                        }

                        ForEach(GoalCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                HStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.caption2)
                                    Text(category.rawValue)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? Color(hex: category.color) : Color(.systemGray6))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)

                // Goals list
                if filteredGoals.isEmpty {
                    emptyStateView
                } else {
                    goalsList
                }
            }
            .navigationTitle("My Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddGoalView()
            }
            .sheet(item: $selectedGoal) { goal in
                GoalDetailView(goal: goal)
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total",
                value: "\(allGoals.count)",
                icon: "target",
                color: .purple
            )

            StatCard(
                title: "In Progress",
                value: "\(allGoals.filter { $0.status == .inProgress }.count)",
                icon: "circle.lefthalf.filled",
                color: .blue
            )

            StatCard(
                title: "Completed",
                value: "\(allGoals.filter { $0.status == .completed }.count)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding()
    }

    private var goalsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredGoals) { goal in
                    GoalCard(goal: goal)
                        .onTapGesture {
                            selectedGoal = goal
                        }
                        .contextMenu {
                            Button(action: { togglePrivacy(goal) }) {
                                Label(
                                    goal.isPrivate ? "Make Public" : "Make Private",
                                    systemImage: goal.isPrivate ? "lock.open" : "lock"
                                )
                            }

                            Button(role: .destructive, action: { deleteGoal(goal) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))

            Text(searchText.isEmpty ? "No goals yet" : "No matching goals")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ?
                 "Set your first goal and start tracking your progress" :
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            if searchText.isEmpty {
                Button(action: { showingAddSheet = true }) {
                    Label("Create Goal", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func togglePrivacy(_ goal: Goal) {
        withAnimation {
            goal.isPrivate.toggle()
            goal.updatedDate = Date()
        }
    }

    private func deleteGoal(_ goal: Goal) {
        withAnimation {
            modelContext.delete(goal)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    @Bindable var goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.icon)
                    .foregroundColor(Color(hex: goal.color))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(goal.category.rawValue)
                            .font(.caption2)
                            .foregroundColor(Color(hex: goal.category.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: goal.category.color).opacity(0.1))
                            .cornerRadius(6)

                        Text(goal.status.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if goal.isPrivate {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    Image(systemName: goal.status.icon)
                        .foregroundColor(statusColor(goal.status))
                }
            }

            if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Text("\(Int(goal.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: goal.color))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: goal.color))
                            .frame(width: geometry.size.width * goal.progress)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: goal.progress)
                    }
                }
                .frame(height: 8)
            }

            if let deadline = goal.deadline {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("Due \(deadline, style: .relative)")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func statusColor(_ status: GoalStatus) -> Color {
        switch status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .onHold: return .orange
        }
    }
}

#Preview {
    GoalsDashboardView()
        .modelContainer(for: [Goal.self, GoalTask.self])
}
