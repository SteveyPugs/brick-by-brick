import SwiftUI

struct Build: Identifiable, Codable {
    let id: UUID
    let title: String
    let motivation: String
    let createdAt: Date
}

@MainActor
final class BuildStore: ObservableObject {
    @Published private(set) var builds: [Build] = []
    @Published private(set) var loadError: String?
    private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrickByBrick", isDirectory: true)
        fileURL = folder.appendingPathComponent("builds-v1.json")
        load()
    }

    func load() {
        do {
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch CocoaError.fileReadNoSuchFile {
                builds = []
                loadError = nil
                return
            }
            builds = try JSONDecoder().decode([Build].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
            loadError = nil
        } catch {
            loadError = "Your saved Builds couldn’t be opened. They haven’t been changed. Please try again."
        }
    }

    func create(title: String, motivation: String) throws {
        guard loadError == nil else { throw SaveError.unavailable }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, cleanTitle.count <= 80 else { throw SaveError.invalidTitle }
        let build = Build(id: UUID(), title: cleanTitle,
                          motivation: motivation.trimmingCharacters(in: .whitespacesAndNewlines),
                          createdAt: Date())
        let updated = [build] + builds
        let data = try JSONEncoder().encode(updated)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        builds = updated
    }

    enum SaveError: Error { case unavailable, invalidTitle }
}

@main
struct BrickByBrickApp: App {
    @StateObject private var store = BuildStore()

    var body: some Scene {
        WindowGroup {
            BuildsView(store: store)
                .tint(Color(red: 0.31, green: 0.41, blue: 0.33))
        }
    }
}

struct BuildsView: View {
    @ObservedObject var store: BuildStore
    @State private var showingCreate = false

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
                                    BuildDetailView(build: build)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(build.title).font(.headline)
                                        if !build.motivation.isEmpty {
                                            Text(build.motivation)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        Text("Ready for your first Wall")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create a Build", systemImage: "plus") { showingCreate = true }
                        .disabled(store.loadError != nil)
                        .accessibilityIdentifier("add-build")
                }
            }
            .sheet(isPresented: $showingCreate) { CreateBuildView(store: store) }
        }
    }
}

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

struct BuildDetailView: View {
    let build: Build

    var body: some View {
        List {
            Section {
                Text(build.title).font(.title2.bold())
                if !build.motivation.isEmpty { Text(build.motivation).foregroundStyle(.secondary) }
            }
            Section("Walls") {
                Label("A little structure, one step at a time", systemImage: "rectangle.split.3x1")
                Text("Your Build is saved. Adding Walls and Bricks is the next piece we’re building.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Your Build")
        .navigationBarTitleDisplayMode(.inline)
    }
}
