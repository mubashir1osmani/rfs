import SwiftUI

struct DayView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var blockToProtect: CalendarBlock?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 23) {
                    summary
                    if !viewModel.calendarConnected {
                        calendarConnection
                    }
                    if !viewModel.conflicts.isEmpty {
                        conflicts
                    }
                    schedule
                    tasks
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color.noriBackground)
            .navigationTitle("My day")
            .toolbarBackground(Color.noriBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await viewModel.refreshSchedule() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.pulse, isActive: viewModel.isRefreshingSchedule)
                    }
                    .disabled(viewModel.isRefreshingSchedule)
                    .accessibilityLabel("Refresh calendars")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.send("Plan and time block my day around my open priorities")
                    } label: {
                        Label("Plan for me", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.noriBackground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.noriMint, in: Capsule())
                    }
                }
            }
            .confirmationDialog(
                "Why is this time protected?",
                isPresented: Binding(
                    get: { blockToProtect != nil },
                    set: { if !$0 { blockToProtect = nil } }
                ),
                titleVisibility: .visible
            ) {
                protectionButton("Exam or study prep")
                protectionButton("Deep work")
                protectionButton("Presentation prep")
                protectionButton("Family or personal time")
                Button("Cancel", role: .cancel) { blockToProtect = nil }
            } message: {
                Text("Nori will watch this block and flag events that threaten it.")
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            summaryValue("\(viewModel.protectedBlocksToday.count)", label: "protected blocks")
            Divider().overlay(Color.noriBorder).padding(.horizontal, 28)
            summaryValue("\(viewModel.conflicts.count)", label: "need decisions")
            Spacer()
        }
        .noriCard(padding: 17)
    }

    private var calendarConnection: some View {
        Button(action: viewModel.connectSystemCalendar) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.noriMint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch your real calendar")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.noriText)
                    Text("Connect Apple Calendar to detect changes around protected time.")
                        .font(.caption)
                        .foregroundStyle(Color.noriMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.noriMuted)
            }
            .noriCard(padding: 15)
        }
    }

    private var conflicts: some View {
        VStack(spacing: 11) {
            SectionHeader(title: "NEEDS A DECISION", action: "\(viewModel.conflicts.count) CONFLICT\(viewModel.conflicts.count == 1 ? "" : "S")")
            ForEach(viewModel.conflicts.prefix(4)) { conflict in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(Color.noriPeach)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(conflict.protectedBlock.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.noriText)
                            Text(conflict.summary)
                                .font(.caption)
                                .foregroundStyle(Color.noriMuted)
                        }
                        Spacer()
                    }
                    Button("Review options with Nori") { viewModel.resolve(conflict) }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.noriBackground)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.noriPeach, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(15)
                .background(Color.noriPeach.opacity(0.08), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.noriPeach.opacity(0.3)) }
            }
        }
    }

    private var schedule: some View {
        VStack(spacing: 11) {
            SectionHeader(title: "SCHEDULE", action: "TODAY")
            VStack(spacing: 0) {
                if viewModel.todayEvents.isEmpty {
                    EmptyState(title: "Your day is open", detail: "Refresh your calendar or ask Nori to reserve focus time.")
                }
                ForEach(viewModel.todayEvents) { event in
                    HStack(spacing: 13) {
                        Text(event.start.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(Color.noriMuted)
                            .frame(width: 64, alignment: .leading)
                        Capsule()
                            .fill(color(named: event.colorName))
                            .frame(width: 3, height: 43)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(event.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.noriText)
                                if event.isProtected {
                                    Image(systemName: "shield.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.noriMint)
                                }
                            }
                            Text(event.isProtected
                                 ? "\(event.durationMinutes) min · \(event.protectionReason ?? "Protected")"
                                 : "\(event.durationMinutes) min · \(sourceLabel(event.source))")
                                .font(.caption2)
                                .foregroundStyle(Color.noriMuted)
                        }
                        Spacer()
                        Button {
                            if event.isProtected {
                                viewModel.setProtection(event, reason: nil)
                            } else {
                                blockToProtect = event
                            }
                        } label: {
                            Image(systemName: event.isProtected ? "shield.slash" : "shield")
                                .foregroundStyle(event.isProtected ? Color.noriPeach : Color.noriMuted)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(event.isProtected ? "Remove protection from \(event.title)" : "Protect \(event.title)")
                    }
                    .padding(.vertical, 9)
                }
            }
        }
    }

    private func protectionButton(_ reason: String) -> some View {
        Button(reason) {
            guard let blockToProtect else { return }
            viewModel.setProtection(blockToProtect, reason: reason)
            self.blockToProtect = nil
        }
    }

    private func sourceLabel(_ source: CalendarBlock.Source) -> String {
        switch source {
        case .nori: "Planned by Nori"
        case .google: "Google Calendar"
        case .system: "Apple Calendar"
        case .seed: "Demo"
        }
    }

    private var tasks: some View {
        VStack(spacing: 11) {
            SectionHeader(title: "TASKS", action: "\(viewModel.tasks.filter { !$0.isCompleted }.count) LEFT")
            VStack(spacing: 0) {
                if viewModel.tasks.isEmpty {
                    EmptyState(title: "Nothing left today", detail: "Enjoy the space, or ask Nori to plan tomorrow.")
                } else {
                    ForEach(viewModel.tasks) { task in
                        TaskRow(task: task) { viewModel.toggleTask(task) }
                        if task.id != viewModel.tasks.last?.id {
                            Divider().overlay(Color.noriBorder)
                        }
                    }
                }
            }
            .noriCard(padding: 13)
        }
    }

    private func summaryValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(Color.noriText)
            Text(label).font(.caption2).foregroundStyle(Color.noriMuted)
        }
    }

    private func color(named name: String) -> Color {
        switch name {
        case "violet": .noriViolet
        case "yellow": .noriYellow
        case "blue": .noriBlue
        default: .noriMint
        }
    }
}
