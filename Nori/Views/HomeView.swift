import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingQuickCapture = false
    @State private var quickTask = ""

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private var openTaskCount: Int {
        viewModel.tasks.filter { !$0.isCompleted }.count
    }

    private var protectedHours: Int {
        (viewModel.protectedMinutesToday + 59) / 60
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 22) {
                    header
                    commandCard
                    metrics
                    nextUp
                    priorities
                    nudge
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color.noriBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingQuickCapture) {
                quickCaptureSheet
                    .presentationDetents([.height(290)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.noriRaised)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(1.3)
                    .foregroundStyle(Color.noriMuted)
                Text("\(greeting),")
                    .font(.title.weight(.medium))
                    .foregroundStyle(Color.noriText)
                Text("Mubashir.")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.noriMint)
            }
            Spacer()
            ZStack(alignment: .bottomTrailing) {
                Text("M")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Color.noriBackground)
                    .frame(width: 46, height: 46)
                    .background(Color.noriMint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Circle()
                    .fill(Color.noriGreen)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.noriBackground, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
            .accessibilityLabel("Mubashir, online")
        }
        .padding(.top, 16)
    }

    private var commandCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Color.noriMint)
                Spacer()
                Label("AUTONOMY ON", systemImage: "circle.fill")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Color.noriMint)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.noriGreen.opacity(0.14), in: Capsule())
            }
            Text("What can I take off your mind?")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.noriText)
            Text("Talk naturally. I’ll plan it, schedule it, or draft it.")
                .font(.subheadline)
                .foregroundStyle(Color.noriMuted)

            Button {
                viewModel.selectedTab = .assistant
            } label: {
                HStack {
                    Text("Ask Nori anything…")
                        .foregroundStyle(Color.noriMuted)
                    Spacer()
                    Image(systemName: "waveform")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.noriBackground)
                        .frame(width: 40, height: 40)
                        .background(Color.noriMint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .frame(minHeight: 54)
                .background(Color.noriBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel("Open Nori assistant")

            HStack(spacing: 10) {
                promptButton("Plan my day", icon: "calendar.badge.clock") {
                    viewModel.send("Plan and time block my day around my priorities")
                }
                promptButton("Book a meeting", icon: "person.2") {
                    viewModel.send("Book a 30 minute meeting tomorrow at 3 PM")
                }
            }

            Button(action: viewModel.runDemo) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NEW TO NORI?")
                            .font(.caption2.weight(.heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.noriMuted)
                        Text("Watch a 20-second action demo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.noriText)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Color.noriMint)
                }
                .padding(13)
                .background(Color.noriBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .accessibilityHint("Shows a task, calendar block, meeting invite, and email draft")
        }
        .padding(19)
        .background {
            ZStack(alignment: .topTrailing) {
                Color.noriRaised
                Circle()
                    .fill(Color.noriGreen.opacity(0.16))
                    .frame(width: 190, height: 190)
                    .blur(radius: 8)
                    .offset(x: 75, y: -105)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.noriMint.opacity(0.25))
        }
    }

    private var metrics: some View {
        HStack(spacing: 9) {
            MetricCard(value: "\(openTaskCount)", label: "open priorities", color: .noriMint)
            MetricCard(value: "\(protectedHours)h", label: "time protected", color: .noriViolet)
            MetricCard(value: "\(viewModel.conflicts.count)", label: "need decisions", color: viewModel.conflicts.isEmpty ? .noriYellow : .noriPeach)
        }
    }

    private var nextUp: some View {
        VStack(spacing: 11) {
            SectionHeader(title: "NEXT UP", action: viewModel.nextEvent?.start.formatted(date: .omitted, time: .shortened) ?? "CLEAR")
            HStack(spacing: 13) {
                Text(viewModel.nextEvent?.start.formatted(date: .omitted, time: .shortened) ?? "—")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.noriText)
                    .frame(width: 63, alignment: .leading)
                Capsule().fill(Color.noriMint).frame(width: 3, height: 42)
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.nextEvent?.title ?? "Your calendar is open")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.noriText)
                    Text(viewModel.nextEvent.map { "\($0.durationMinutes) minutes · \($0.source == .nori ? "Planned by Nori" : "Calendar")" } ?? "Ask Nori to protect focus time")
                        .font(.caption2)
                        .foregroundStyle(Color.noriMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.noriMuted)
            }
            .noriCard(padding: 14)
        }
    }

    private var priorities: some View {
        VStack(spacing: 11) {
            SectionHeader(title: "PRIORITIES", action: "TODAY")
            VStack(spacing: 0) {
                ForEach(viewModel.tasks.prefix(4)) { task in
                    TaskRow(task: task) { viewModel.toggleTask(task) }
                    if task.id != viewModel.tasks.prefix(4).last?.id {
                        Divider().overlay(Color.noriBorder)
                    }
                }
            }
            .noriCard(padding: 13)

            Button {
                showingQuickCapture = true
            } label: {
                Label("Capture a task", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.noriMuted)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.noriBorder, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    }
            }
        }
    }

    private var nudge: some View {
        Button {
            if let conflict = viewModel.conflicts.first {
                viewModel.resolve(conflict)
            } else if viewModel.protectedBlocksToday.isEmpty {
                viewModel.selectedTab = .day
            } else {
                viewModel.send("Review my protected time today and tell me what needs attention")
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill").foregroundStyle(Color.noriYellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NORI NOTICED")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.noriYellow)
                    Text(nudgeText)
                        .font(.caption)
                        .foregroundStyle(Color.noriText.opacity(0.78))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.noriMuted)
            }
            .padding(15)
            .background(Color.noriYellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.noriYellow.opacity(0.24)) }
        }
    }

    private var nudgeText: String {
        if let conflict = viewModel.conflicts.first {
            return conflict.summary
        }
        if viewModel.protectedBlocksToday.isEmpty {
            return "Nothing is protected today. Mark the time that should not get hijacked."
        }
        return "Your \(viewModel.protectedBlocksToday.count) protected block\(viewModel.protectedBlocksToday.count == 1 ? " is" : "s are") clear right now."
    }

    private func promptButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.noriMint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.noriMint.opacity(0.09), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private var quickCaptureSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("What needs your attention?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.noriText)
                TextField("Finish the presentation", text: $quickTask)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.noriBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.noriText)
                    .submitLabel(.done)
                    .onSubmit(addQuickTask)
                Button(action: addQuickTask) {
                    Label("Add to my day", systemImage: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(Color.noriBackground)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.noriMint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .disabled(quickTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding(20)
            .background(Color.noriRaised)
        }
    }

    private func addQuickTask() {
        viewModel.addTask(title: quickTask)
        quickTask = ""
        showingQuickCapture = false
    }
}
