import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 13) {
                        Text("M")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.noriBackground)
                            .frame(width: 48, height: 48)
                            .background(Color.noriMint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mubashir").font(.headline).foregroundStyle(Color.noriText)
                            Text("Student · Builder · Getting things done")
                                .font(.caption)
                                .foregroundStyle(Color.noriMuted)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("AUTONOMY") {
                    Toggle(isOn: $viewModel.autonomyEnabled) {
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
                        subtitle: "Syncs with Google when configured in iOS",
                        icon: "calendar",
                        color: .noriBlue,
                        isConnected: viewModel.connections.calendar
                    ) { viewModel.toggleConnection(\.calendar) }
                    connectionRow(
                        title: "Gmail",
                        subtitle: "Direct send through the secure backend",
                        icon: "envelope",
                        color: .noriPeach,
                        isConnected: viewModel.connections.gmail
                    ) { viewModel.toggleConnection(\.gmail) }
                }

                Section("AI ENGINE") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Nori Intelligence", systemImage: "brain.head.profile")
                            .font(.headline)
                            .foregroundStyle(Color.noriText)
                        Text(AppConfiguration.current.assistantURL == nil ? "Smart local planner" : "Secure AI backend connected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.noriGreen)
                        Text("Nori keeps private provider keys on the server and sends only the context needed to plan your request.")
                            .font(.caption)
                            .foregroundStyle(Color.noriMuted)
                    }
                    .padding(.vertical, 5)
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

    private func connectionRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isConnected: Bool,
        action: @escaping () -> Void
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
            Button(isConnected ? "Connected" : "Connect", action: action)
                .font(.caption.weight(.bold))
                .foregroundStyle(isConnected ? Color.noriMint : Color.noriBackground)
                .padding(.horizontal, 11)
                .frame(minHeight: 40)
                .background(isConnected ? Color.noriGreen.opacity(0.14) : Color.noriMint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(.vertical, 3)
    }
}
