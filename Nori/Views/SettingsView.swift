import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    private let configuration = AppConfiguration.current
    @State private var backendToken = ""
    @State private var hasBackendToken = CredentialStore.appToken() != nil

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
                    connectionRow(
                        title: "Gmail",
                        subtitle: configuration.usesRemoteExecution ? "Direct send through your backend" : "Opens a reviewable Mail draft",
                        icon: "envelope",
                        color: .noriPeach,
                        status: configuration.usesRemoteExecution ? "Backend" : "Mail app"
                    )
                }

                Section("AI ENGINE") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Nori Intelligence", systemImage: "brain.head.profile")
                            .font(.headline)
                            .foregroundStyle(Color.noriText)
                        Text(configuration.usesRemoteAssistant ? "AI backend configured" : "Smart local planner")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.noriGreen)
                        Text("Nori keeps private provider keys on the server and sends only the context needed to plan your request.")
                            .font(.caption)
                            .foregroundStyle(Color.noriMuted)
                    }
                    .padding(.vertical, 5)
                }

                if configuration.usesRemoteAssistant || configuration.usesRemoteExecution {
                    Section("BACKEND ACCESS") {
                        SecureField("Access token", text: $backendToken)
                            .textContentType(.password)
                            .privacySensitive()
                        Button(hasBackendToken ? "Replace secure token" : "Save secure token") {
                            saveBackendToken()
                        }
                        .disabled(backendToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if hasBackendToken {
                            Button("Remove token", role: .destructive) {
                                removeBackendToken()
                            }
                        }
                        Text("The token stays in this device’s Keychain and is never bundled with the app.")
                            .font(.caption)
                            .foregroundStyle(Color.noriMuted)
                    }
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

    private func saveBackendToken() {
        do {
            try CredentialStore.setAppToken(backendToken)
            backendToken = ""
            hasBackendToken = true
        } catch {
            viewModel.activeError = error.localizedDescription
        }
    }

    private func removeBackendToken() {
        do {
            try CredentialStore.setAppToken("")
            backendToken = ""
            hasBackendToken = false
        } catch {
            viewModel.activeError = error.localizedDescription
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
