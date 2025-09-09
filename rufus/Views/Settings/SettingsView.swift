//
//  SettingsView.swift
//  rufus
//
//  Created by AI Assistant on 2025-07-25.
//


import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthService.shared

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("annoyanceLevel") private var annoyanceLevel = 2 // 1-3 (low, medium, high)
    @AppStorage("earlyReminderMinutes") private var earlyReminderMinutes = 30
    
    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                
                if notificationsEnabled {
                    Picker("Annoyance Level", selection: $annoyanceLevel) {
                        Text("Gentle").tag(1)
                        Text("Moderate").tag(2)
                        Text("EXTREMELY ANNOYING").tag(3)
                    }
                    .pickerStyle(.segmented)
                    
                    Stepper("Early Reminder (minutes): \(earlyReminderMinutes)", 
                            value: $earlyReminderMinutes, 
                            in: 5...120, 
                            step: 5)
                }
            }
            
            Section("Calendar Integration") {
                NavigationLink(destination: CalendarConnectionsView()) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.blue)
                        Text("Connect Calendars")
                    }
                }
            }
            
            Section("AI Assistant") {
                NavigationLink(destination: LLMSettingsView()) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("LLM Settings")
                    }
                }
            }
        
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            }
            
            Section("Account") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(authService.user?.email ?? "Student")
                            .font(.headline)
                        Text("Signed in")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button("Sign Out") {
                        Task {
                            try? await authService.signOut()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
