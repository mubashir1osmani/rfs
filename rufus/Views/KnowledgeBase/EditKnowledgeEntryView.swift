//
//  EditKnowledgeEntryView.swift
//  rufus
//
//  Edit existing knowledge entry
//

import SwiftUI
import SwiftData

struct EditKnowledgeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: KnowledgeEntry

    @State private var tagInput = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Note Details")) {
                    TextField("Title", text: $entry.title)
                        .font(.headline)

                    Picker("Category", selection: $entry.category) {
                        ForEach(KnowledgeEntry.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section(header: Text("Content")) {
                    TextEditor(text: $entry.content)
                        .frame(minHeight: 200)
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

                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(entry.tags, id: \.self) { tag in
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
                    Toggle(isOn: $entry.isPrivate) {
                        Label("Private Note", systemImage: "lock.fill")
                            .foregroundColor(.green)
                    }

                    Toggle(isOn: $entry.isFavorite) {
                        Label("Mark as Favorite", systemImage: "star.fill")
                            .foregroundColor(.orange)
                    }
                }

                Section(header: Text("Metadata")) {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(entry.createdDate, style: .date)
                            .foregroundColor(.gray)
                    }
                    .font(.caption)

                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(entry.updatedDate, style: .relative)
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        entry.updatedDate = Date()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !entry.tags.contains(trimmed) {
            entry.tags.append(trimmed)
            tagInput = ""
            entry.updatedDate = Date()
        }
    }

    private func removeTag(_ tag: String) {
        entry.tags.removeAll { $0 == tag }
        entry.updatedDate = Date()
    }
}
