//
//  LLMSettingsView.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-11.
//

import SwiftUI
import SwiftData

struct LLMSettingsView: View {
    @ObservedObject private var groqService = GroqService.shared
    @State private var apiKey: String = KeychainHelper.shared.read(forKey: "groqApiKey") ?? UserDefaults.standard.string(forKey: "groqApiKey") ?? ""
    @State private var selectedModel: String = UserDefaults.standard.string(forKey: "groqSelectedModel") ?? "llama3-70b-8192"
    @State private var showApiKeySaved: Bool = false
    
    @AppStorage("llmEnabled") private var llmEnabled: Bool = false
    @AppStorage("smartRemindersEnabled") private var smartRemindersEnabled: Bool = false
    @AppStorage("dailyBriefingEnabled") private var dailyBriefingEnabled: Bool = false
    @AppStorage("dailyBriefingTime") private var dailyBriefingTime: Double = 9.0 // 9:00 AM default
    
    var body: some View {
        Form {
            Section(header: Text("LLM Configuration")) {
                Toggle("Enable LLM Features", isOn: $llmEnabled)
                    .onChange(of: llmEnabled) { newValue, _ in
                        // If enabling and no API key, show info
                        if newValue && !groqService.hasValidApiKey {
                            showApiKeySaved = true
                        }
                    }
                
                if llmEnabled {
                    HStack {
                        SecureField("Groq API Key", text: $apiKey)
                        
                        Button(action: {
                            groqService.saveApiKey(apiKey)
                            showApiKeySaved = true
                        }) {
                            Text("Save")
                        }
                        .disabled(apiKey.isEmpty)
                    }
                    
                    if showApiKeySaved {
                        Text(groqService.hasValidApiKey ? "API key saved" : "Please enter an API key")
                            .font(.caption)
                            .foregroundColor(groqService.hasValidApiKey ? .green : .orange)
                    }
                    
                    Picker("Model", selection: $selectedModel) {
                        ForEach(Array(groqService.availableModels.keys), id: \.self) { modelId in
                            Text(groqService.availableModels[modelId] ?? modelId)
                                .tag(modelId)
                        }
                    }
                    .onChange(of: selectedModel) { newValue, _ in
                        groqService.setSelectedModel(newValue)
                    }
                }
            }
            
            if llmEnabled && groqService.hasValidApiKey {
                Section(header: Text("Smart Features")) {
                    Toggle("Smart Assignment Reminders", isOn: $smartRemindersEnabled)
                    
                    Toggle("Daily Briefing", isOn: $dailyBriefingEnabled)
                    
                    if dailyBriefingEnabled {
                        HStack {
                            Text("Daily Briefing Time")
                            Spacer()
                            Text(timeString(from: dailyBriefingTime))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $dailyBriefingTime, in: 5...23, step: 0.5) {
                            Text("Daily Briefing Time")
                        } minimumValueLabel: {
                            Text("5 AM")
                        } maximumValueLabel: {
                            Text("11 PM")
                        }
                    }
                }
                
                Section(header: Text("Ask Rufus")) {
                    NavigationLink(destination: AskRufusView()) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.purple)
                            Text("Ask Rufus Assistant")
                        }
                    }
                }
            }
            
            Section(header: Text("About Groq Integration")) {
                Text("Rufus uses Groq's advanced LLM capabilities to provide personalized assistance with your courses, assignments, and schedule.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if llmEnabled {
                    Text("Note: You'll need your own Groq API key. Get one at [groq.com](https://console.groq.com/keys).")
                        .font(.footnote)
                        .tint(.blue)
                }
            }
        }
        .navigationTitle("LLM Settings")
    }
    
    private func timeString(from value: Double) -> String {
        let hour = Int(value)
        let minute = Int((value.truncatingRemainder(dividingBy: 1)) * 60)
        
        let amPm = hour < 12 ? "AM" : "PM"
        let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        
        return String(format: "%d:%02d %@", hour12, minute, amPm)
    }
}

struct AskRufusView: View {
    @StateObject private var groqService = GroqService.shared
    @State private var userQuery: String = ""
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    @Query private var assignments: [Assignment]
    @Query private var courses: [Course]
    @Environment(\.modelContext) private var modelContext
    
    @State private var calendarEvents: [CalendarEvent] = []
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Ask Rufus")
                .font(.largeTitle)
                .bold()
            
            Text("Ask anything about your assignments, schedule, or courses")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            // Response area
            ScrollView {
                if !responseText.isEmpty {
                    Text(responseText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                } else if isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Thinking...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    Text("Ask me about your upcoming assignments, schedule conflicts, or how to manage your workload!")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            
            // Input area
            HStack {
                TextField("Ask Rufus...", text: $userQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                
                Button(action: {
                    sendQuery()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(userQuery.isEmpty || isLoading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(userQuery.isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Load calendar events when the view appears
            Task {
                await loadCalendarEvents()
            }
        }
    }
    
    private func sendQuery() {
        isLoading = true
        
        // Prepare context with all relevant data
        let context: [String: Any] = [
            "assignments": assignments,
            "courses": courses,
            "calendarEvents": calendarEvents
        ]
        
        Task {
            do {
                let response = try await groqService.generateAssistantResponse(prompt: userQuery, conversationHistory: [])
                
                await MainActor.run {
                    responseText = response
                    isLoading = false
                    // Clear input after sending
                    userQuery = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func loadCalendarEvents() async {
        // Get calendar service and fetch events
        let calendarService = CalendarService.shared
        
        // Date range for next 30 days
        let now = Date()
        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .day, value: 30, to: now) else { return }
        
        do {
            let events = try await calendarService.loadAllCalendarEvents(from: now, to: endDate)
            await MainActor.run {
                self.calendarEvents = events
            }
        } catch {
            print("Failed to load calendar events: \(error.localizedDescription)")
            // We'll still continue even if calendar events can't be loaded
        }
    }
}

#Preview {
    NavigationStack {
        LLMSettingsView()
    }
}
