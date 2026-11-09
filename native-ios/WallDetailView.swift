import SwiftUI

struct WallDetailView: View {
    @ObservedObject var store: BuildStore
    let buildID: UUID
    let wallID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreate = false
    @State private var showingRename = false
    @State private var brickToRename: Brick?
    @State private var brickToMeasure: Brick?
    @State private var confirmingDelete = false
    @State private var brickToDelete: Brick?
    @State private var showingError = false
    private var wall: Wall? {
        store.builds.first { $0.id == buildID }?.walls.first { $0.id == wallID }
    }

    var body: some View {
        List {
          if let wall = wall {
            Section { Text(wall.title).font(.title2.bold()) }
            Section("Bricks") {
                if wall.bricks.isEmpty {
                    Text("A Brick is a small action, like reading for 10 minutes. Add one and tap it when you’re done.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(wall.bricks.filter { $0.isComplete }.count) of \(wall.bricks.count) complete")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("brick-progress")
                }
                ForEach(wall.bricks) { brick in
                    HStack {
                        Button {
                            if brick.kind == .yesNo {
                                do { try store.toggleBrick(buildID: buildID, wallID: wallID, brickID: brick.id) }
                                catch { showingError = true }
                            } else { brickToMeasure = brick }
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Label(brick.title, systemImage: brick.isComplete ? "checkmark.circle.fill" : "circle")
                                    .strikethrough(brick.isComplete)
                                if brick.kind != .yesNo { Text(brick.progressLabel).font(.caption) }
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(brick.title)
                        .accessibilityValue(brick.kind == .yesNo ? (brick.isComplete ? "Complete" : "Incomplete") : brick.progressLabel)
                        .accessibilityHint(brick.kind == .yesNo ? "Double tap to change completion" : "Double tap to record progress")
                        Spacer()
                        Button { brickToRename = brick } label: {
                            Image(systemName: "pencil").frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit \(brick.title)")
                        Button(role: .destructive) { brickToDelete = brick } label: {
                            Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Delete \(brick.title)")
                    }
                }
                Button("Add a Brick", systemImage: "plus") { showingCreate = true }
                    .accessibilityIdentifier("add-brick")
            }
            Section {
                Button("Delete Wall", role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("delete-wall")
            }
          }
        }
        .navigationTitle("Your Wall")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit name") { showingRename = true }.accessibilityIdentifier("edit-wall") }
        .sheet(isPresented: $showingRename) {
            NameEditor(title: wall?.title ?? "", heading: "Edit Wall") {
                try store.rename(buildID: buildID, wallID: wallID, title: $0)
            }
        }
        .sheet(item: $brickToRename) { brick in
            NameEditor(title: brick.title, heading: "Edit Brick") {
                try store.rename(buildID: buildID, wallID: wallID, brickID: brick.id, title: $0)
            }
        }
        .sheet(item: $brickToMeasure) { brick in
            ProgressEditor(brick: brick) {
                try store.recordProgress(buildID: buildID, wallID: wallID, brickID: brick.id, value: $0)
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateBrickView(store: store, buildID: buildID, wallID: wallID)
        }
        .alert("Delete this Wall?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Wall", role: .destructive) {
                do { try store.deleteWall(buildID: buildID, wallID: wallID); dismiss() }
                catch { showingError = true }
            }
        } message: { Text("This permanently deletes this Wall and all its Bricks. This cannot be undone.") }
        .alert("Delete this Brick?", isPresented: Binding(
            get: { brickToDelete != nil }, set: { if !$0 { brickToDelete = nil } }
        ), presenting: brickToDelete) { brick in
            Button("Cancel", role: .cancel) { brickToDelete = nil }
            Button("Delete Brick", role: .destructive) {
                do { try store.deleteBrick(buildID: buildID, wallID: wallID, brickID: brick.id) }
                catch { showingError = true }
                brickToDelete = nil
            }
        } message: { brick in Text("Permanently delete “\(brick.title)” and its completion status? This cannot be undone.") }
        .alert("Change wasn’t saved", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Your saved data hasn’t changed. Please try again.") }
    }
}

