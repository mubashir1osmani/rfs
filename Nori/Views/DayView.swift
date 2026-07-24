import SwiftUI

struct DayView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 23) {
                    summary
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
        }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            summaryValue("\(viewModel.calendarBlocks.count)", label: "calendar blocks")
            Divider().overlay(Color.noriBorder).padding(.horizontal, 28)
            summaryValue("\(viewModel.tasks.filter { !$0.isCompleted }.count)", label: "priorities left")
            Spacer()
        }
        .noriCard(padding: 17)
    }

    private var schedule: some View {
        VStack(spacing: 11) {
            SectionHeader(title: "SCHEDULE", action: "TODAY")
            VStack(spacing: 0) {
                ForEach(viewModel.orderedEvents) { event in
                    HStack(spacing: 13) {
                        Text(event.start.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(Color.noriMuted)
                            .frame(width: 64, alignment: .leading)
                        Capsule()
                            .fill(color(named: event.colorName))
                            .frame(width: 3, height: 43)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.noriText)
                            Text("\(event.durationMinutes) min\(event.source == .nori ? " · Planned by Nori" : "")")
                                .font(.caption2)
                                .foregroundStyle(Color.noriMuted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 9)
                }
            }
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
