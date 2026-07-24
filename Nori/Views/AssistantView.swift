import SwiftUI

struct AssistantView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var speechRecognizer: SpeechRecognizer
    @FocusState private var composerFocused: Bool
    private let configuration = AppConfiguration.current

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        speechRecognizer = viewModel.speechRecognizer
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(
                                message: message,
                                actionStates: viewModel.actionStates,
                                onExecute: { action in await viewModel.execute(action) },
                                onDismiss: viewModel.dismiss
                            )
                            .id(message.id)
                        }
                        if viewModel.isThinking {
                            HStack(spacing: 10) {
                                ProgressView().tint(Color.noriMint)
                                Text("Nori is making a plan…")
                                    .font(.caption)
                                    .foregroundStyle(Color.noriMuted)
                                Spacer()
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Nori is making a plan")
                        }
                    }
                    .frame(maxWidth: 620)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .background(Color.noriBackground)
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .navigationTitle("Nori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.noriBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("NORI")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.noriText)
                        Text("AUTONOMOUS ASSISTANT")
                            .font(.system(size: 8, weight: .heavy))
                            .tracking(1.1)
                            .foregroundStyle(Color.noriMuted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Label(configuration.usesRemoteAssistant ? "AI backend" : "Local", systemImage: "circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.noriMint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.noriGreen.opacity(0.13), in: Capsule())
                }
            }
            .onChange(of: speechRecognizer.transcript) { _, transcript in
                viewModel.composerText = transcript
            }
            .alert("Voice input", isPresented: Binding(
                get: { speechRecognizer.errorMessage != nil },
                set: { if !$0 { speechRecognizer.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { speechRecognizer.errorMessage = nil }
            } message: {
                Text(speechRecognizer.errorMessage ?? "")
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 9) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    suggestion("Plan my day")
                    suggestion("Block focus time")
                    suggestion("Draft an email")
                    suggestion("Book a meeting")
                }
                .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    speechRecognizer.toggle()
                } label: {
                    Image(systemName: speechRecognizer.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .symbolEffect(.pulse, isActive: speechRecognizer.isListening)
                        .foregroundStyle(speechRecognizer.isListening ? Color.noriPeach : Color.noriMint)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(speechRecognizer.isListening ? "Stop listening" : "Talk to Nori")

                TextField("Tell Nori what you need…", text: $viewModel.composerText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .foregroundStyle(Color.noriText)
                    .padding(.vertical, 12)

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.noriBackground)
                        .frame(width: 40, height: 40)
                        .background(Color.noriMint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .disabled(viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isThinking)
                .opacity(viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.noriSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.noriBorder) }
            .frame(maxWidth: 620)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
    }

    private func suggestion(_ title: String) -> some View {
        Button(title) { viewModel.send(title) }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.noriMint)
            .padding(.horizontal, 13)
            .frame(minHeight: 40)
            .background(Color.noriSurface, in: Capsule())
            .overlay { Capsule().stroke(Color.noriBorder) }
    }

    private func send() {
        speechRecognizer.stop()
        viewModel.send()
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    let actionStates: [String: ActionState]
    let onExecute: (AssistantAction) async -> Void
    let onDismiss: (AssistantAction) -> Void

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            if message.role == .assistant {
                Label("NORI", systemImage: "sparkles")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color.noriMuted)
            }
            Text(message.text)
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(message.role == .user ? Color.noriBackground : Color.noriText)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    message.role == .user ? Color.noriMint : Color.noriSurface,
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                )
                .overlay {
                    if message.role == .assistant {
                        RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.noriBorder)
                    }
                }
                .frame(maxWidth: 480, alignment: message.role == .user ? .trailing : .leading)

            ForEach(message.actions) { action in
                ActionCard(
                    action: action,
                    state: actionStates[action.id],
                    onExecute: { await onExecute(action) },
                    onDismiss: { onDismiss(action) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
