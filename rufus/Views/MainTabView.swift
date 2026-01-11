//
//  MainTabView.swift
//  rufus
//
//

import SwiftUI

struct MainTabView: View {
    @State private var isVoiceSheetPresented = false

    var body: some View {
        TabView {
            DashboardView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isVoiceSheetPresented = true
                        } label: {
                            Image(systemName: "mic.fill")
                        }
                        .accessibilityLabel("Voice Assistant")
                    }
                }
                .sheet(isPresented: $isVoiceSheetPresented) {
                    VoiceAssistantView()
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            NavigationStack {
                AssignmentsListView()
            }
            .tabItem {
                Image(systemName: "list.bullet.clipboard.fill")
                Text("Tasks")
            }

            GoalsDashboardView()
                .tabItem {
                    Image(systemName: "target")
                    Text("Goals")
                }

            KnowledgeBaseView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Notes")
                }

            ChatView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Chat")
                }
        }
    }
}

#Preview {
    MainTabView()
}
