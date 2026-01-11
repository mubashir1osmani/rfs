//
//  AssignmentsListView.swift
//  rufus
//
//  Created by AI Assistant on 2025-07-25.
//

import SwiftUI
import SwiftData

struct AssignmentsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [Assignment]
    @Query private var courses: [Course]
    
    @State private var showingAddAssignment = false
    @State private var selectedCourse: Course?
    @State private var showCompletedAssignments = true
    
    private var filteredAssignments: [Assignment] {
        var filtered = assignments
        
        // Filter by course if selected
        if let selectedCourse = selectedCourse {
            filtered = filtered.filter { $0.course?.id == selectedCourse.id }
        }
        
        // Filter by completion status
        if !showCompletedAssignments {
            filtered = filtered.filter { !$0.isCompleted }
        }
        
        // Sort by due date
        return filtered.sorted { $0.dueDate < $1.dueDate }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Filter controls
                if !courses.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // All courses button
                            FilterChip(
                                title: "All",
                                isSelected: selectedCourse == nil,
                                icon: "list.bullet"
                            ) {
                                selectedCourse = nil
                            }
                            
                            // Individual course buttons
                            ForEach(courses.sorted(by: { $0.name < $1.name })) { course in
                                FilterChip(
                                    title: course.code.isEmpty ? course.name : course.code,
                                    isSelected: selectedCourse?.id == course.id,
                                    icon: "book.fill"
                                ) {
                                    selectedCourse = selectedCourse?.id == course.id ? nil : course
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }
                
                List {
                    if filteredAssignments.isEmpty {
                        ContentUnavailableView(
                            "No Assignments",
                            systemImage: "list.bullet",
                            description: Text(selectedCourse == nil ? 
                                "Add your first assignment to get started." : 
                                "No assignments found for \(selectedCourse?.displayName ?? "this course")."
                            )
                        )
                    } else {
                        ForEach(filteredAssignments) { assignment in
                            AssignmentRowView(assignment: assignment)
                        }
                        .onDelete(perform: deleteAssignments)
                    }
                }
            }
            .navigationTitle("Assignments")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: {
                            showCompletedAssignments.toggle()
                        }) {
                            Label(
                                showCompletedAssignments ? "Hide Completed" : "Show Completed",
                                systemImage: showCompletedAssignments ? "eye.slash" : "eye"
                            )
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddAssignment = true
                    }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAssignment) {
                AddAssignmentView()
            }
        }
    }
    
    private func deleteAssignments(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredAssignments[index])
            }
        }
    }
}

#Preview {
    NavigationStack {
        AssignmentsListView()
    }
    .modelContainer(for: Assignment.self, inMemory: true)
}
