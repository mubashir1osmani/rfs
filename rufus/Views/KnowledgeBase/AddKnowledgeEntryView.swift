//
//  AddKnowledgeEntryView.swift
//  rufus
//
//  Add new knowledge entry
//

import SwiftUI
import SwiftData

struct AddKnowledgeEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var selectedCategory = "General"
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var isPrivate = true
    @State private var isFavorite = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Note Details")) {
                    TextField("Title", text: $title)
                        .font(.headline)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(KnowledgeEntry.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section(header: Text("Content")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .font(.body)
                }

                Section(header: Text("Tags")) {
                    HStack {
                        TextField("Add tag", text: $tagInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                        }
                        .disabled(tagInput.isEmpty)
                    }

                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text("#\(tag)")
                                            .font(.caption)
                                        Button(action: { removeTag(tag) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Privacy")) {
                    Toggle(isOn: $isPrivate) {
                        Label("Private Note", systemImage: "lock.fill")
                            .foregroundColor(.green)
                    }

                    Toggle(isOn: $isFavorite) {
                        Label("Mark as Favorite", systemImage: "star.fill")
                            .foregroundColor(.orange)
                    }
                }

                Section {
                    Text("Private notes are stored locally and never synced to the cloud.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            tagInput = ""
        }
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func saveEntry() {
        let entry = KnowledgeEntry(
            title: title,
            content: content,
            category: selectedCategory,
            tags: tags,
            isPrivate: isPrivate,
            isFavorite: isFavorite
        )

        modelContext.insert(entry)
        dismiss()
    }
}

#Preview {
    AddKnowledgeEntryView()
        .modelContainer(for: [KnowledgeEntry.self])
}
