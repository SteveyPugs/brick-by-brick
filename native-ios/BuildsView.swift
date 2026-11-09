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
                    List {
                        Section {
                            Text("Meaningful things are built one brick at a time.")
                                .foregroundStyle(.secondary)
                        }
                        Section("Your Builds") {
                            ForEach(store.builds) { build in
                                NavigationLink {
                                    BuildDetailView(store: store, buildID: build.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(build.title).font(.headline)
                                        if !build.motivation.isEmpty {
                                            Text(build.motivation)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        Text(build.walls.isEmpty ? "Ready for your first Wall" : "\(build.walls.count) \(build.walls.count == 1 ? "Wall" : "Walls")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        CompletionSummary(bricks: build.walls.flatMap { $0.bricks })
                                    }
                                    .padding(.vertical, 6)
                                }
                                .accessibilityIdentifier("build-row")
                            }
                        }
                        Section {
                            Label("Saved on this device", systemImage: "iphone")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
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

