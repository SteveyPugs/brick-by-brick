import SwiftUI

struct CreateWallView: View {
    @ObservedObject var store: BuildStore
    let buildID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var showingSaveError = false
    @FocusState private var titleFocused: Bool
    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Move more", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Wall name")
                        .accessibilityIdentifier("wall-name")
                } header: {
                    Text("Name your Wall")
                } footer: {
                    Text(cleanTitle.count > 80 ? "Keep your name to 80 characters or fewer." : "Choose one part of your goal to focus on.")
                }
            }
            .navigationTitle("Add a Wall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        do {
                            try store.createWall(buildID: buildID, title: title)
                            dismiss()
                        } catch { showingSaveError = true }
                    }
                    .disabled(cleanTitle.isEmpty || cleanTitle.count > 80)
                    .accessibilityIdentifier("save-wall")
                }
            }
            .onAppear { titleFocused = true }
            .interactiveDismissDisabled(!title.isEmpty)
            .alert("Wall wasn’t saved", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your draft is still here. Please try again. If it keeps happening, check your device’s available storage.")
            }
        }
    }
}

