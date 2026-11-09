import SwiftUI

struct BuildsView: View {
    @ObservedObject var store: BuildStore
    @State private var showingCreate = false
    @State private var showingPlanner = false

    var body: some View {
        NavigationStack {
            Group {
                if let message = store.loadError {
                    ContentUnavailableView {
                        Label("Couldn’t load Builds", systemImage: "exclamationmark.icloud")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { store.load() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if store.builds.isEmpty {
                    ContentUnavailableView {
                        Label("What will you build?", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("A Build is a goal that matters to you. Start with one; we’ll break it into Walls and Bricks as we go.")
                    } actions: {
                        Button("Create a Build") { showingCreate = true }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("create-first-build")
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            Text("One brick at a time.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ForEach(store.builds) { build in
                                NavigationLink {
                                    BuildDetailView(store: store, buildID: build.id)
                                } label: {
                                    BuildCard(build: build)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("build-row")
                            }
                            Label("Saved on this device", systemImage: "iphone")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            }
            .navigationTitle("Builds")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Help me build this", systemImage: "sparkles") { showingPlanner = true }
                        .disabled(store.loadError != nil)
                        .accessibilityIdentifier("open-planner")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create a Build", systemImage: "plus") { showingCreate = true }
                        .disabled(store.loadError != nil)
                        .accessibilityIdentifier("add-build")
                }
            }
            .sheet(isPresented: $showingCreate) { CreateBuildView(store: store) }
            .sheet(isPresented: $showingPlanner) { PlannerView(store: store) }
        }
    }
}

private struct BuildCard: View {
    let build: Build
    @Environment(\.brickToday) private var today
    private var bricks: [Brick] { build.walls.flatMap { $0.bricks } }
    private var due: [Brick] { Brick.dueBricks(bricks, on: today) }
    private var completed: Int { due.filter { $0.isComplete }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(BrickStyle.accent)
                    .frame(width: 40, height: 40)
                    .background(BrickStyle.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(build.title).font(.title3.bold()).foregroundStyle(.primary)
                    if !build.motivation.isEmpty {
                        Text(build.motivation).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary).accessibilityHidden(true)
            }
            if !build.walls.isEmpty {
                Text("\(build.walls.count) \(build.walls.count == 1 ? "Wall" : "Walls")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if bricks.isEmpty {
                Text(build.walls.isEmpty ? "Ready for your first Wall" : "Ready for your first Brick")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                if !due.isEmpty {
                    ProgressView(value: Double(completed), total: Double(due.count))
                        .accessibilityHidden(true)
                }
                CompletionSummary(bricks: bricks)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

