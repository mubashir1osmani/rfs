// VoiceAssistantView.swift
// SwiftUI UI for the assistant: mic control, live transcript, and spoken responses.

import SwiftUI

struct VoiceAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VoiceAssistantViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You said")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(model.transcript.isEmpty ? "(Tap the mic and start speaking)" : model.transcript)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxHeight: 160)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Assistant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.response.isEmpty ? "(I'll respond here and speak back)" : model.response)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                Button(action: { model.toggleListening() }) {
                    ZStack {
                        Circle()
                            .fill(model.isListening ? Color.red.opacity(0.85) : Color.accentColor)
                            .frame(width: 72, height: 72)
                        Image(systemName: model.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .accessibilityLabel(model.isListening ? "Stop Listening" : "Start Listening")
            }
            .padding()
            .navigationTitle("Voice Assistant")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await model.requestPermissions() }
        }
    }
}

#Preview {
    VoiceAssistantView()
}
