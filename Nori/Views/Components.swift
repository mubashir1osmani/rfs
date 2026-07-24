import SwiftUI

struct SectionHeader: View {
    let title: String
    let action: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.noriMuted)
            Spacer()
            Text(action)
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Color.noriGreen)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.noriMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .noriCard(padding: 13)
        .accessibilityElement(children: .combine)
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.noriMint : task.category.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(task.isCompleted ? Color.noriMuted : Color.noriText)
                        .strikethrough(task.isCompleted)
                    Text("\(task.dueLabel) · \(task.category.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(Color.noriMuted)
                }
                Spacer(minLength: 8)
                Capsule()
                    .fill(task.category.color)
                    .frame(width: 4, height: 26)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityValue(task.isCompleted ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to toggle completion")
    }
}

struct ActionCard: View {
    let action: AssistantAction
    let state: ActionState?
    let onExecute: () async -> Void
    let onDismiss: () -> Void

    @State private var isExecuting = false

    private var title: String {
        action.kind == .email ? action.subject ?? "Email draft" : action.title ?? "New action"
    }

    private var detail: String {
        switch action.kind {
        case .task:
            return "\(action.dueLabel ?? "Today") · \(action.category?.rawValue ?? "Personal")"
        case .calendar, .meeting:
            let time = action.startDate.formatted(date: .abbreviated, time: .shortened)
            let attendees = action.attendees?.isEmpty == false ? " · \(action.attendees!.joined(separator: ", "))" : ""
            return "\(time) · \(action.durationMinutes ?? 60) min\(attendees)"
        case .email:
            return "\(action.to?.isEmpty == false ? action.to! : "Choose recipient") · Ready to review"
        }
    }

    private var buttonTitle: String {
        switch action.kind {
        case .task: "Add task"
        case .calendar: "Add to Calendar"
        case .meeting: "Create invite"
        case .email: "Review email"
        }
    }

    var body: some View {
        if state == .dismissed {
            Text("Action dismissed")
                .font(.caption)
                .foregroundStyle(Color.noriMuted)
                .frame(maxWidth: .infinity)
                .padding()
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.noriBorder)
                }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    Image(systemName: action.kind.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(action.kind.color)
                        .frame(width: 32, height: 32)
                        .background(action.kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(action.kind.title)
                        .font(.caption2.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(action.kind.color)
                    Spacer()
                    if state == nil {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.noriMuted)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Dismiss \(action.kind.title.lowercased())")
                    }
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.noriText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.noriMuted)

                if action.kind == .email, let body = action.body {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(Color.noriMuted)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.noriBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    Task {
                        isExecuting = true
                        await onExecute()
                        isExecuting = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isExecuting {
                            ProgressView().tint(Color.noriBackground)
                        } else {
                            Text(state == .completed ? "Added to your day" : buttonTitle)
                            Image(systemName: state == .completed ? "checkmark" : "arrow.right")
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.noriBackground)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(state == .completed ? Color.noriGreen.opacity(0.55) : Color.noriMint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .disabled(state == .completed || isExecuting)
            }
            .padding(15)
            .background(Color.noriRaised, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(action.kind.color.opacity(0.35))
            }
        }
    }
}

struct EmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(Color.noriMint)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.noriText)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.noriMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 145)
        .padding(.horizontal, 24)
    }
}
