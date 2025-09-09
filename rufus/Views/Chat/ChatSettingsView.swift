//
//  ChatSettingsView.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-17.
//

import SwiftUI

struct ChatSettingsView: View {
    @AppStorage("chatAutoSuggestions") private var autoSuggestions = true
    @AppStorage("chatQuickActions") private var quickActions = true
    @AppStorage("chatNotifications") private var notifications = true
    @AppStorage("chatVoiceInput") private var voiceInput = false
    @AppStorage("chatDarkMode") private var chatDarkMode = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Chat Preferences")) {
                    Toggle("Auto Suggestions", isOn: $autoSuggestions)
                        .help("Show suggested actions when starting a conversation")
                    
                    Toggle("Quick Actions", isOn: $quickActions)
                        .help("Enable quick action buttons in chat")
                    
                    Toggle("Voice Input", isOn: $voiceInput)
                        .help("Enable voice-to-text input (coming soon)")
                        .disabled(true)
                }
                
                Section(header: Text("AI Behavior")) {
                    Toggle("Smart Notifications", isOn: $notifications)
                        .help("Allow AI to send proactive notifications about deadlines")
                    
                    Toggle("Chat Dark Mode", isOn: $chatDarkMode)
                        .help("Use dark theme for chat interface")
                        .disabled(true)
                }
                
                Section(header: Text("Privacy")) {
                    HStack {
                        Text("Data Storage")
                        Spacer()
                        Text("Local Only")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear Chat History") {
                        // TODO: Implement clear history
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("AI Model")
                        Spacer()
                        Text("Groq Llama-3")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ChatSettingsView()
}
