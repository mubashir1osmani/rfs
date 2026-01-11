//
//  DashboardView.swift
//  beacon
//
//  Created by AI Assistant on 2025-07-25.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [Assignment]
    @StateObject private var authService = AuthService.shared
    
    @State private var showingAddAssignment = false
    @State private var showingDropdown = false
    @State private var selectedDate = Date()
    @State private var showingChat = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section (card-like)
                        VStack(spacing: 16) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Hello \(getUserName()) 👋")
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text("Plan your day and stay focused")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Avatar / menu
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(LinearGradient(colors: [Color(.systemBlue), Color(.systemTeal)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Text(getInitials())
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        )

                                    Button(action: { showingDropdown.toggle() }) {
                                        Image(systemName: "line.3.horizontal")
                                            .font(.title3)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        
                        // Notebook Row
                        NavigationLink(destination: NotebookView()) {
                            HStack {
                                Image(systemName: "text.book.closed.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading) {
                                    Text("Quick Notebook")
                                        .font(.headline)
                                    Text("Jot down quick thoughts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal)
                        .buttonStyle(PlainButtonStyle())
                        
                        // Calendar Widget
                        CalendarWidgetView(selectedDate: $selectedDate, assignments: assignments)
                            .padding(.horizontal)

                        // Prayer Times Section
                        PrayerTimesView()
                            .padding(.horizontal)

                        // Daily Briefing (LLM-powered)
                        if UserDefaults.standard.bool(forKey: "llmEnabled") && 
                           UserDefaults.standard.bool(forKey: "dailyBriefingEnabled") {
                            DailyBriefingView()
                                .padding(.horizontal)
                        }
                        
                        // Tasks Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Today's Tasks")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Spacer()

                                Button("See All") {
                                    // Handle see all action
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)

                            TaskListWidget(
                                title: "Active Tasks", 
                                assignments: incompleteAssignments, 
                                showingAddAssignment: $showingAddAssignment
                            )
                            .padding(.horizontal)
                        }

                        // Quick Add Section
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)

                                Text("Add new task")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                            .onTapGesture {
                                showingAddAssignment = true
                            }
                        }
                        .padding(.horizontal)

                        // Bottom spacing
                        Color.clear
                            .frame(height: 80)
                    }
                    .padding(.top)
                }
                .navigationBarHidden(true)

                // Floating voice chat button (bottom-right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        Button(action: { showingChat = true }) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(.systemPurple), Color(.systemBlue)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 64, height: 64)
                                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 6)

                                Image(systemName: "mic.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                        .accessibilityLabel("Voice Chat")
                        .accessibilityHint("Open voice chat assistant")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAssignment) {
            AddAssignmentView()
        }
        .sheet(isPresented: $showingChat) {
            ChatView()
        }
        .overlay(alignment: .topTrailing) {
            if showingDropdown {
                DropdownMenu(isPresented: $showingDropdown)
                    .padding(.top, 100)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private func getUserName() -> String {
        if let user = authService.user, let email = user.email {
            return email.components(separatedBy: "@").first?.capitalized ?? "User"
        }
        return "Mubashir"
    }
    
    private func getInitials() -> String {
        if let user = authService.user, let email = user.email {
            let name = email.components(separatedBy: "@").first ?? "U"
            let parts = name.split(separator: ".")
            if parts.count >= 2 {
                let firstInitial = parts[0].first.map { String($0) } ?? "U"
                let secondInitial = parts[1].first.map { String($0) } ?? ""
                return (firstInitial + secondInitial).uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        return "MO"
    }
    
    private var incompleteAssignments: [Assignment] {
        assignments.filter { !$0.isCompleted }.prefix(5).map { $0 }
    }
}

// ... rest of DashboardView remains the same
