//
//  ChatView.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-17.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @StateObject private var chatService = ChatService()
    @StateObject private var speechService = SpeechService()
    @StateObject private var textToSpeechService = TextToSpeechService()
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingSettings = false
    
    // Enum to manage the state of the voice assistant
    enum AssistantState {
        case idle
        case listening
        case processing
    }
    
    @State private var assistantState: AssistantState = .idle
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatService.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: chatService.messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                Spacer()
                
                // Voice interaction UI
                voiceInteractionView()
                    .padding()
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    
                    Menu {
                        Button("Clear Chat", action: { chatService.clearChat() })
                        Button("Daily Briefing", action: { sendTextMessage("Give me my daily briefing") })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ChatSettingsView()
            }
        }
        .onAppear {
            chatService.setModelContext(modelContext)
        }
        .onChange(of: chatService.lastMessageFromAssistant) { oldMessage, newMessage in
            if let message = newMessage, !message.isEmpty {
                textToSpeechService.speak(text: message)
            }
        }
    }
    
    @ViewBuilder
    private func voiceInteractionView() -> some View {
        VStack {
            Text(assistantState == .listening ? speechService.transcribedText : "Tap to speak")
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(height: 50)
                .padding(.horizontal)

            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .frame(width: 70, height: 70)
                        .foregroundColor(assistantState == .listening ? .red : .blue)
                        .scaleEffect(assistantState == .listening ? 1.1 : 1.0)
                    
                    if assistantState == .processing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                }
            }
            .animation(.spring(), value: assistantState)
        }
    }
    
    private func toggleRecording() {
        if assistantState == .listening {
            speechService.stopRecording()
            assistantState = .processing
            // Send the transcribed text
            sendTextMessage(speechService.transcribedText)
        } else {
            textToSpeechService.stopSpeaking()
            speechService.startRecording()
            assistantState = .listening
        }
    }
    
    private func sendTextMessage(_ message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            assistantState = .idle
            return
        }
        
        Task {
            await chatService.sendMessage(trimmedMessage)
            assistantState = .idle
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = chatService.messages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatView()
}