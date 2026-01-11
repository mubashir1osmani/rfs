//
//  ChatService.swift
//  rufus
//
//  Created by AI Assistant
//

import Foundation

@MainActor
class ChatService: ObservableObject {
    static let shared = ChatService()

    @Published var messages: [ChatMessage] = []
    @Published var lastMessageFromAssistant: String?

    private var modelContext: Any?

    private init() {}

    func sendMessage(_ text: String) async throws -> String {
        return "Response to: \(text)"
    }

    func clearHistory() {
        messages.removeAll()
    }

    func clearChat() {
        messages.removeAll()
    }

    func setModelContext(_ context: Any) {
        self.modelContext = context
    }
}
