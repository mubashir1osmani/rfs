import SwiftUI
import SwiftData

struct NotebookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var newNoteText: String = ""
    @FocusState private var isInputActive: Bool

    var body: some View {
        ZStack {
            // Paper Background
            NotebookBackground()
                .ignoresSafeArea()

            VStack {
                // Notes List
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(notes) { note in
                            NoteRow(note: note)
                        }
                    }
                    .padding(.top, 40) // Space for the top of the paper
                }

                // Input Area
                HStack(spacing: 12) {
                    TextField("Jot something down...", text: $newNoteText)
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                        .focused($isInputActive)
                        .submitLabel(.done)
                        .onSubmit(addNote)

                    Button(action: addNote) {
                        Image(systemName: "pencil.and.outline")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Circle().fill(Color(.systemBackground).opacity(0.8)))
                    }
                    .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Notebook")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addNote() {
        guard !newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let note = Note(content: newNoteText)
        modelContext.insert(note)
        newNoteText = ""
        isInputActive = false
    }
}

struct NoteRow: View {
    let note: Note
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(alignment: .top) {
            // Margin spacing
            Rectangle()
                .fill(Color.clear)
                .frame(width: 50)

            Text(note.content)
                .font(.custom("Snell Roundhand", size: 22).italic()) // A script font for handwriting feel
                .foregroundColor(.black.opacity(0.8))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { modelContext.delete(note) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.3))
            }
            .padding(.trailing, 20)
            .padding(.top, 12)
        }
        .frame(minHeight: 32) // Match the line height of the background
    }
}

struct NotebookBackground: View {
    var body: some View {
        ZStack(alignment: .leading) {
            // Paper color
            Color(red: 0.98, green: 0.98, blue: 0.95)

            // Horizontal Lines
            GeometryReader { geometry in
                Path { path in
                    let lineHeight: CGFloat = 32
                    let numberOfLines = Int(geometry.size.height / lineHeight)
                    
                    for i in 0...numberOfLines {
                        let y = CGFloat(i) * lineHeight
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            }

            // Vertical Margin Line
            Rectangle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 2)
                .padding(.leading, 45)
        }
    }
}

#Preview {
    NavigationStack {
        NotebookView()
    }
    .modelContainer(for: Note.self, inMemory: true)
}
