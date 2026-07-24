import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject private var google = GoogleOAuthService.shared
    private let configuration = AppConfiguration.current
    @State private var openAIKey = ""
    @State private var hasOpenAIKey = CredentialStore.openAIKey != nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 13) {
                        Image(systemName: "person.fill")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.noriBackground)
                            .frame(width: 48, height: 48)
                            .background(Color.noriMint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your Nori").font(.headline).foregroundStyle(Color.noriText)
                            Text("Personal planning workspace")
                                .font(.caption)
                                .foregroundStyle(Color.noriMuted)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("AUTONOMY") {
                    Toggle(isOn: Binding(
                        get: { viewModel.autonomyEnabled },
                        set: viewModel.setAutonomyEnabled
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Act on safe requests").foregroundStyle(Color.noriText)
                                Text("Tasks are automatic. External actions require approval.")
                                    .font(.caption)
                                    .foregroundStyle(Color.noriMuted)
                            }
                        } icon: {
                            Image(systemName: "sparkles").foregroundStyle(Color.noriMint)
                        }
                    }
                    .tint(Color.noriGreen)
                }

                Section("CONNECTIONS") {
                    connectionRow(
                        title: "System Calendar",
                        subtitle: "Permission is requested when you approve an event",
                        icon: "calendar",
                        color: .noriBlue,
                        status: "On device"
                    )
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .foregroundStyle(Color.noriPeach)
                            .frame(width: 37, height: 37)
                            .background(Color.noriPeach.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Google Workspace").font(.subheadline.weight(.semibold)).foregroundStyle(Color.noriText)
                            Text("Calendar events and Gmail sending").font(.caption2).foregroundStyle(Color.noriMuted)
                        }
                        Spacer()
                        Button(google.isConnected ? "Disconnect" : (google.isConnecting ? "Connecting" : "Connect")) {
                            toggleGoogleConnection()
                        }
                        .disabled(google.isConnecting)
                        .font(.caption.weight(.bold))
                    }
                    .padding(.vertical, 3)
                }

                Section("AI ENGINE") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Nori Intelligence", systemImage: "brain.head.profile")
                            .font(.headline)
                            .foregroundStyle(Color.noriText)
                        Text(configuration.usesRemoteAssistant ? "OpenAI · GPT Realtime 2.1" : "Smart local planner")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.noriGreen)
                        Text("Your OpenAI key stays in this device’s Keychain. Nori sends requests directly to OpenAI.")
                            .font(.caption)
                            .foregroundStyle(Color.noriMuted)
                    }
                    .padding(.vertical, 5)
                }

                Section("OPENAI ACCESS") {
                    SecureField("OpenAI API key", text: $openAIKey)
                        .textContentType(.password)
                        .privacySensitive()
                    Button(hasOpenAIKey ? "Replace secure key" : "Save secure key") {
                        saveOpenAIKey()
                    }
                    .disabled(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasOpenAIKey {
                        Button("Remove key", role: .destructive) {
                            removeOpenAIKey()
                        }
                    }
                    Text("Use a personal project key. Never embed a shared OpenAI key in a distributed app.")
                        .font(.caption)
                        .foregroundStyle(Color.noriMuted)
                }

                Section("APPROVAL BOUNDARY") {
                    Text("Nori plans proactively. Messages, guest invitations, and external calendar changes remain visible and reviewable before they happen.")
                        .font(.caption)
                        .foregroundStyle(Color.noriMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.noriBackground)
            .foregroundStyle(Color.noriText)
            .navigationTitle("Settings")
            .toolbarBackground(Color.noriBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func saveOpenAIKey() {
        do {
            try CredentialStore.setOpenAIKey(openAIKey)
            openAIKey = ""
            hasOpenAIKey = true
        } catch {
            viewModel.activeError = error.localizedDescription
        }
    }

    private func removeOpenAIKey() {
        do {
            try CredentialStore.setOpenAIKey("")
            openAIKey = ""
            hasOpenAIKey = false
        } catch {
            viewModel.activeError = error.localizedDescription
        }
    }

    private func toggleGoogleConnection() {
        Task {
            do {
                if google.isConnected { try google.disconnect() }
                else { try await google.connect() }
            } catch {
                viewModel.activeError = error.localizedDescription
            }
        }
    }

    private func connectionRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        status: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 37, height: 37)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.noriText)
                Text(subtitle).font(.caption2).foregroundStyle(Color.noriMuted)
            }
            Spacer()
            Text(status)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.noriMint)
                .padding(.horizontal, 11)
                .frame(minHeight: 40)
                .background(Color.noriGreen.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(.vertical, 3)
    }
}
