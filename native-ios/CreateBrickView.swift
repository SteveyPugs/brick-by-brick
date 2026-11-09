import SwiftUI

struct CreateBrickView: View {
    @ObservedObject var store: BuildStore
    let buildID: UUID
    let wallID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind: BrickKind = .yesNo
    @State private var target = "1"
    @State private var unit = ""
    @State private var showingError = false
    @FocusState private var titleFocused: Bool
    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Read for 10 minutes", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Brick name")
                        .accessibilityIdentifier("brick-name")
                } header: { Text("Name your Brick") }
                  footer: { Text(cleanTitle.count > 80 ? "Keep your name to 80 characters or fewer." : "Choose one small action you can complete.") }
                MeasurementFields(kind: $kind, target: $target, unit: $unit)
            }
            .navigationTitle("Add a Brick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        do { try store.createBrick(buildID: buildID, wallID: wallID, title: title,
                                                  kind: kind, target: NumberInput.parse(target) ?? 1, unit: unit); dismiss() }
                        catch { showingError = true }
                    }
                    .disabled(cleanTitle.isEmpty || cleanTitle.count > 80 || !NumberInput.validTarget(kind: kind, target: target, unit: unit))
                    .accessibilityIdentifier("save-brick")
                }
            }
            .onAppear { titleFocused = true }
            .interactiveDismissDisabled(!title.isEmpty)
            .alert("Brick wasn’t saved", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: { Text("Your draft is still here. Please try again.") }
        }
    }
}
// Bricks are one-time actions in this release; no automatic daily reset.
