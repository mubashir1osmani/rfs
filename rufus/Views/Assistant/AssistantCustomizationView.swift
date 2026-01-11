//
//  AssistantCustomizationView.swift
//  rufus
//
//  Customize personal assistant personality and behavior
//

import SwiftUI
import SwiftData

struct AssistantCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AssistantSettings]

    @State private var settings: AssistantSettings?
    @State private var assistantName = "Rufus"
    @State private var selectedStyle: CommunicationStyle = .casual
    @State private var selectedResponseLength: ResponseLength = .normal
    @State private var selectedLearningStyle: LearningStyle = .balanced
    @State private var reminderFrequency: ReminderFrequency = .moderate
    @State private var quietHoursEnabled = false
    @State private var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var focusAreas: [String] = ["study", "productivity"]
    @State private var preferredSubjects: [String] = []
    @State private var customPrompt = ""
    @State private var assistantEmoji = "🦊"

    let availableEmojis = ["🦊", "🐶", "🐱", "🐻", "🐼", "🦁", "🦉", "🐰", "🦋", "🌟"]

    var body: some View {
        NavigationStack {
            Form {
                // Identity section
                identitySection

                // Communication style
                communicationSection

                // Learning preferences
                learningSection

                // Notification preferences
                notificationSection

                // Advanced
                advancedSection

                // Preview
                previewSection
            }
            .navigationTitle("Customize Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadSettings()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var identitySection: some View {
        Section(header: Text("Assistant Identity")) {
            HStack {
                Text("Emoji")
                    .foregroundColor(.gray)

                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableEmojis, id: \.self) { emoji in
                            Button(action: { assistantEmoji = emoji }) {
                                Text(emoji)
                                    .font(.title)
                                    .frame(width: 50, height: 50)
                                    .background(assistantEmoji == emoji ? Color.purple.opacity(0.2) : Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            }

            TextField("Assistant Name", text: $assistantName)
                .font(.headline)
        }
    }

    private var communicationSection: some View {
        Section(header: Text("Communication Style")) {
            ForEach(CommunicationStyle.allCases, id: \.self) { style in
                Button(action: { selectedStyle = style }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(style.emoji)
                                Text(style.rawValue)
                                    .fontWeight(.semibold)
                            }

                            Text(style.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if selectedStyle == style {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.purple)
                        }
                    }
                }
                .foregroundColor(.primary)
            }

            Picker("Response Length", selection: $selectedResponseLength) {
                ForEach(ResponseLength.allCases, id: \.self) { length in
                    VStack(alignment: .leading) {
                        Text(length.rawValue)
                        Text(length.description)
                            .font(.caption)
                    }
                    .tag(length)
                }
            }
        }
    }

    private var learningSection: some View {
        Section(header: Text("Learning Preferences")) {
            Picker("Learning Style", selection: $selectedLearningStyle) {
                ForEach(LearningStyle.allCases, id: \.self) { style in
                    HStack {
                        Image(systemName: style.icon)
                        Text(style.rawValue)
                    }
                    .tag(style)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Focus Areas")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                FlowLayout(spacing: 8) {
                    ForEach(["study", "productivity", "wellness", "organization", "creativity"], id: \.self) { area in
                        FocusAreaChip(
                            title: area,
                            isSelected: focusAreas.contains(area),
                            action: { toggleFocusArea(area) }
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var notificationSection: some View {
        Section(header: Text("Notifications")) {
            Picker("Reminder Frequency", selection: $reminderFrequency) {
                ForEach(ReminderFrequency.allCases, id: \.self) { frequency in
                    VStack(alignment: .leading) {
                        Text(frequency.rawValue)
                        Text(frequency.description)
                            .font(.caption)
                    }
                    .tag(frequency)
                }
            }

            Toggle("Quiet Hours", isOn: $quietHoursEnabled)

            if quietHoursEnabled {
                DatePicker("Start", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
            }
        }
    }

    private var advancedSection: some View {
        Section(header: Text("Advanced"), footer: Text("Custom instructions for your assistant. This will be added to every conversation.")) {
            TextEditor(text: $customPrompt)
                .frame(minHeight: 100)
                .overlay(
                    Group {
                        if customPrompt.isEmpty {
                            Text("Add custom instructions...")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
        }
    }

    private var previewSection: some View {
        Section(header: Text("Preview")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(assistantEmoji)
                        .font(.largeTitle)

                    VStack(alignment: .leading) {
                        Text(assistantName)
                            .font(.headline)
                        Text(selectedStyle.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Text("Sample response:")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(getSampleResponse())
                    .font(.subheadline)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(10)
            }
        }
    }

    private func toggleFocusArea(_ area: String) {
        if focusAreas.contains(area) {
            focusAreas.removeAll { $0 == area }
        } else {
            focusAreas.append(area)
        }
    }

    private func getSampleResponse() -> String {
        switch selectedStyle {
        case .formal:
            return "Good afternoon. I have reviewed your schedule and identified three priority tasks requiring your attention today."
        case .casual:
            return "Hey! I checked out your schedule and found 3 important tasks you should focus on today 😊"
        case .motivational:
            return "You're doing amazing! Let's tackle these 3 priority tasks today and keep that momentum going! 💪"
        case .concise:
            return "3 priority tasks today."
        }
    }

    private func loadSettings() {
        if let existing = allSettings.first {
            settings = existing
            assistantName = existing.assistantName
            selectedStyle = existing.communicationStyle
            selectedResponseLength = existing.responseLength
            selectedLearningStyle = existing.learningStyle
            reminderFrequency = existing.reminderFrequency
            quietHoursEnabled = existing.quietHoursEnabled
            if let start = existing.quietHoursStart {
                quietHoursStart = start
            }
            if let end = existing.quietHoursEnd {
                quietHoursEnd = end
            }
            focusAreas = existing.focusAreas
            preferredSubjects = existing.preferredSubjects
            customPrompt = existing.customSystemPrompt ?? ""
            assistantEmoji = existing.assistantEmoji
        }
    }

    private func saveSettings() {
        if let existing = settings {
            // Update existing
            existing.assistantName = assistantName
            existing.communicationStyle = selectedStyle
            existing.responseLength = selectedResponseLength
            existing.learningStyle = selectedLearningStyle
            existing.reminderFrequency = reminderFrequency
            existing.quietHoursEnabled = quietHoursEnabled
            existing.quietHoursStart = quietHoursEnabled ? quietHoursStart : nil
            existing.quietHoursEnd = quietHoursEnabled ? quietHoursEnd : nil
            existing.focusAreas = focusAreas
            existing.preferredSubjects = preferredSubjects
            existing.customSystemPrompt = customPrompt.isEmpty ? nil : customPrompt
            existing.assistantEmoji = assistantEmoji
            existing.updatedDate = Date()
        } else {
            // Create new
            let newSettings = AssistantSettings(
                assistantName: assistantName,
                communicationStyle: selectedStyle,
                focusAreas: focusAreas,
                responseLength: selectedResponseLength,
                customSystemPrompt: customPrompt.isEmpty ? nil : customPrompt,
                reminderFrequency: reminderFrequency,
                quietHoursEnabled: quietHoursEnabled,
                preferredSubjects: preferredSubjects,
                learningStyle: selectedLearningStyle,
                assistantEmoji: assistantEmoji
            )
            newSettings.quietHoursStart = quietHoursEnabled ? quietHoursStart : nil
            newSettings.quietHoursEnd = quietHoursEnabled ? quietHoursEnd : nil

            modelContext.insert(newSettings)
            settings = newSettings
        }
    }
}

// MARK: - Focus Area Chip

struct FocusAreaChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.capitalized)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.purple : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    AssistantCustomizationView()
        .modelContainer(for: [AssistantSettings.self])
}
