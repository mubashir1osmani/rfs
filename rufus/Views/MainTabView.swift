//
//  MainTabView.swift
//  rufus
//
//  Created by AI Assistant on 2025-07-25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Dashboard")
                }
            
            NavigationStack {
                AssignmentsListView()
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Assignments")
            }
            
            NavigationStack {
                CoursesListView()
            }
            .tabItem {
                Image(systemName: "book.closed")
                Text("Courses")
            }
            
            ChatView()
                .tabItem {
                    Image(systemName: "message.circle")
                    Text("AI Chat")
                }
        }
    }
}

#Preview {
    MainTabView()
}
