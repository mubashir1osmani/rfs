//
//  KnowledgeBaseView.swift
//  rufus
//
//  Private knowledge base with search and filtering
//

import SwiftUI
import SwiftData

struct KnowledgeBaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgeEntry.updatedDate, order: .reverse) private var allEntries: [KnowledgeEntry]

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingAddSheet = false
    @State private var selectedEntry: KnowledgeEntry?
    @State private var showFavoritesOnly = false

    var filteredEntries: [KnowledgeEntry] {
        var entries = allEntries

        // Filter by favorites
        if showFavoritesOnly {
            entries = entries.filter { $0.isFavorite }
        }

        // Filter by category
        if selectedCategory != "All" {
            entries = entries.filter { $0.category == selectedCategory }
        }

        // Filter by search text
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.title.localizedCaseInsensitiveContains(searchText) ||
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return entries
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedCategory == "All",
                            icon: "square.grid.2x2"
                        ) {
                            selectedCategory = "All"
                        }

                        ForEach(KnowledgeEntry.categories, id: \.self) { category in
                            FilterChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                icon: iconForCategory(category)
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                // Favorites toggle
                Toggle(isOn: $showFavoritesOnly) {
                    Label("Favorites Only", systemImage: "star.fill")
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Content
                if filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    entriesList
                }
            }
            .navigationTitle("Knowledge Base")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddKnowledgeEntryView()
            }
            .sheet(item: $selectedEntry) { entry in
                EditKnowledgeEntryView(entry: entry)
            }
        }
    }

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredEntries) { entry in
                    KnowledgeEntryCard(entry: entry)
                        .onTapGesture {
                            selectedEntry = entry
                        }
                        .contextMenu {
                            Button(action: { toggleFavorite(entry) }) {
                                Label(
                                    entry.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: entry.isFavorite ? "star.slash" : "star"
                                )
                            }

                            Button(role: .destructive, action: { deleteEntry(entry) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.purple.opacity(0.5))

            Text(searchText.isEmpty ? "No notes yet" : "No matching notes")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ?
                 "Start building your personal knowledge base" :
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            if searchText.isEmpty {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Note", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Study Notes": return "book.fill"
        case "Resources": return "link.circle.fill"
        case "Ideas": return "lightbulb.fill"
        case "Personal": return "person.fill"
        case "Research": return "doc.text.magnifyingglass"
        case "Quick Notes": return "note.text"
        default: return "folder.fill"
        }
    }

    private func toggleFavorite(_ entry: KnowledgeEntry) {
        withAnimation {
            entry.isFavorite.toggle()
            entry.updatedDate = Date()
        }
    }

    private func deleteEntry(_ entry: KnowledgeEntry) {
        withAnimation {
            modelContext.delete(entry)
        }
    }
}

// MARK: - Knowledge Entry Card

struct KnowledgeEntryCard: View {
    let entry: KnowledgeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text(entry.category)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(6)
                }

                Spacer()

                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.orange)
                }

                if entry.isPrivate {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            Text(entry.content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)

            if !entry.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
            }

            Text(entry.updatedDate, style: .relative)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

#Preview {
    KnowledgeBaseView()
        .modelContainer(for: [KnowledgeEntry.self])
}
