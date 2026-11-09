import SwiftUI

struct BuildDetailView: View {
    @ObservedObject var store: BuildStore
    let buildID: UUID
    @State private var showingCreateWall = false
    @State private var showingRename = false
    @State private var confirmingDelete = false
    @State private var showingDeleteError = false
    @Environment(\.dismiss) private var dismiss
    private var build: Build? { store.builds.first { $0.id == buildID } }

    var body: some View {
        List {
          if let build = build {
            Section {
                Text(build.title).font(.title2.bold())
                if !build.motivation.isEmpty { Text(build.motivation).foregroundStyle(.secondary) }
                CompletionSummary(bricks: build.walls.flatMap { $0.bricks })
            }
            Section("Walls") {
                if build.walls.isEmpty {
                    Text("A Wall is one part of your bigger goal. For a healthier you, try Movement, Sleep, or Nutrition.")
                        .foregroundStyle(.secondary)
                }
                ForEach(build.walls) { wall in
                    NavigationLink {
                        WallDetailView(store: store, buildID: buildID, wallID: wall.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(wall.title, systemImage: "rectangle.split.3x1")
                            CompletionSummary(bricks: wall.bricks)
                        }
                    }
                }
                Button("Add a Wall", systemImage: "plus") { showingCreateWall = true }
                    .accessibilityIdentifier("add-wall")
            }
            Section {
                Button("Delete Build", role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("delete-build")
            }
          }
        }
        .navigationTitle("Your Build")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit name") { showingRename = true }.accessibilityIdentifier("edit-build") }
        .sheet(isPresented: $showingRename) {
            NameEditor(title: build?.title ?? "", heading: "Edit Build") {
                try store.rename(buildID: buildID, title: $0)
            }
        }
        .sheet(isPresented: $showingCreateWall) {
            CreateWallView(store: store, buildID: buildID)
        }
        .alert("Delete this Build?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Build", role: .destructive) {
                do { try store.deleteBuild(buildID: buildID); dismiss() }
                catch { showingDeleteError = true }
            }
        } message: {
            Text("This permanently deletes this Build and all its Walls and Bricks. This cannot be undone.")
        }
        .alert("Build wasn’t deleted", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Nothing was removed. Please try again.") }
    }
}

