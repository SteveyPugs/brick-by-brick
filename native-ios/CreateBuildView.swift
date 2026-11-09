import SwiftUI

struct CreateBuildView: View {
    @ObservedObject var store: BuildStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var motivation = ""
    @State private var showingSaveError = false
    @FocusState private var titleFocused: Bool

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Build a healthier me", text: $title, axis: .vertical)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Build name")
                        .accessibilityIdentifier("build-name")
                } header: {
                    Text("Name your Build")
                } footer: {
                    Text(cleanTitle.count > 80 ? "Keep your name to 80 characters or fewer." : "Choose a goal, big or small.")
                }
                Section {
                    TextField("What makes this important to you?", text: $motivation, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Why this matters, optional")
                        .accessibilityIdentifier("build-motivation")
                } header: {
                    Text("Why it matters (optional)")
                } footer: {
                    Text("Your Build stays on this device. No account needed.")
                }
            }
            .navigationTitle("Create a Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        do {
                            try store.create(title: title, motivation: motivation)
                            dismiss()
                        } catch {
                            showingSaveError = true
                        }
                    }
                    .disabled(cleanTitle.isEmpty || cleanTitle.count > 80)
                    .accessibilityIdentifier("save-build")
                }
            }
            .onAppear { titleFocused = true }
            .interactiveDismissDisabled(!title.isEmpty || !motivation.isEmpty)
            .alert("Build wasn’t saved", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your draft is still here. Please try again. If it keeps happening, check your device’s available storage.")
            }
        }
    }
}

