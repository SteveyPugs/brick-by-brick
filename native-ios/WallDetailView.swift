import SwiftUI

struct WallDetailView: View {
    @ObservedObject var store: BuildStore
    let buildID: UUID
    let wallID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.brickToday) private var today
    @State private var showingCreate = false
    @State private var showingRename = false
    @State private var brickToRename: Brick?
    @State private var brickToMeasure: ProgressSelection?
    @State private var confirmingDelete = false
    @State private var brickToDelete: Brick?
    @State private var showingError = false
    private var wall: Wall? {
        store.builds.first { $0.id == buildID }?.walls.first { $0.id == wallID }
    }

    var body: some View {
        List {
          if let wall = wall {
            let due = Brick.dueBricks(wall.bricks, on: today)
            Section { Text(wall.title).font(.title2.bold()) }
            Section("Bricks") {
                if wall.bricks.isEmpty {
                    Text("Add a small action you can check off or track toward a target.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(due.isEmpty ? "No Bricks scheduled today" :
                         "\(due.filter { $0.isComplete }.count) of \(due.count) complete" +
                         (wall.bricks.contains { !$0.repeatDays.isEmpty } ? " today" : ""))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("brick-progress")
                }
                ForEach(wall.bricks) { saved in
                    let brick = saved.occurrence(on: today)
                    let scheduled = brick.isDue(on: today)
                    HStack(spacing: 8) {
                        Button {
                            if brick.kind == .yesNo {
                                do { try store.toggleBrick(buildID: buildID, wallID: wallID, brickID: brick.id) }
                                catch { showingError = true }
                            } else { brickToMeasure = ProgressSelection(brick: brick, date: today) }
                        } label: {
                            BrickRowContent(brick: brick, scheduled: scheduled)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!scheduled)
                        .accessibilityLabel(brick.title)
                        .accessibilityValue(!scheduled ? "Not scheduled today" :
                            brick.kind == .yesNo ? (brick.isComplete ? "Complete" : "Incomplete") : brick.progressLabel)
                        .accessibilityHint(brick.kind == .yesNo ? "Changes completion" : "Opens progress editor")
                        Menu {
                            Button("Rename", systemImage: "pencil") { brickToRename = brick }
                            Button(role: .destructive) { brickToDelete = brick } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Options for \(brick.title)")
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
        .sheet(item: $brickToMeasure) { selection in
            ProgressEditor(brick: selection.brick) {
                try store.recordProgress(buildID: buildID, wallID: wallID, brickID: selection.id, value: $0, on: selection.date)
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

private struct ProgressSelection: Identifiable {
    let brick: Brick
    let date: Date
    var id: UUID { brick.id }
}

private struct BrickRowContent: View {
    let brick: Brick
    let scheduled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: brick.isComplete ? "checkmark.circle.fill" :
                    brick.kind == .yesNo ? "circle" : "chart.bar.fill")
                .font(.title3)
                .foregroundStyle(BrickStyle.accent)
                .frame(width: 36, height: 36)
                .background(BrickStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(brick.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if !scheduled {
                    Text("Not scheduled today").font(.caption).foregroundStyle(.secondary)
                } else if brick.kind != .yesNo {
                    Text("\(brick.progress.formatted()) / \(brick.target.formatted()) \(brick.unit)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if brick.target > 0 {
                        ProgressView(value: min(brick.progress / brick.target, 1))
                    }
                } else {
                    Text(brick.isComplete ? "Done" : "Tap to check off")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !brick.repeatDays.isEmpty {
                    Label(brick.repeatLabel, systemImage: "repeat")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

