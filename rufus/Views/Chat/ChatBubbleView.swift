//
//  ChatBubbleView.swift
//  rufus
//
//  Created by AI Assistant on 2025-08-17.
//

import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            // User bubble tail
                            UserBubbleTail()
                                .fill(Color.blue)
                                .frame(width: 15, height: 10)
                                .offset(x: 8, y: 10),
                            alignment: .bottomTrailing
                        )
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        // AI Avatar
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if message.isThinking {
                                ThinkingIndicator()
                            } else {
                                Text(message.content)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay(
                                        // AI bubble tail
                                        AIBubbleTail()
                                            .fill(Color(.systemGray6))
                                            .frame(width: 15, height: 10)
                                            .offset(x: -8, y: 10),
                                        alignment: .bottomLeading
                                    )
                            }
                        }
                        
                        Spacer(minLength: 60)
                    }
                    
                    if !message.isThinking {
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 38)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct UserBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct AIBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ThinkingIndicator: View {
    @State private var animationAmount = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1 + sin(animationAmount + Double(index) * 0.5) * 0.3)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationAmount
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            AIBubbleTail()
                .fill(Color(.systemGray6))
                .frame(width: 15, height: 10)
                .offset(x: -8, y: 10),
            alignment: .bottomLeading
        )
        .onAppear {
            animationAmount = 1.0
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatBubbleView(message: ChatMessage(content: "Hello! Can you help me add a new assignment?", isUser: true))
        ChatBubbleView(message: ChatMessage(content: "Of course! I'd be happy to help you add a new assignment. Could you tell me the assignment title, due date, and which course it's for?", isUser: false))
        ChatBubbleView(message: ChatMessage(content: "Thinking...", isUser: false, isThinking: true))
    }
    .padding()
}
