import SwiftUI

struct Brick: Identifiable, Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    var isComplete: Bool = false
}

struct Wall: Identifiable, Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    var bricks: [Brick]

    init(id: UUID, title: String, createdAt: Date, bricks: [Brick] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.bricks = bricks
    }

    private enum CodingKeys: String, CodingKey { case id, title, createdAt, bricks }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        bricks = values.contains(.bricks) ? try values.decode([Brick].self, forKey: .bricks) : []
    }
}

struct Build: Identifiable, Codable {
    let id: UUID
    let title: String
    let motivation: String
    let createdAt: Date
    var walls: [Wall]

    init(id: UUID, title: String, motivation: String, createdAt: Date, walls: [Wall] = []) {
        self.id = id
        self.title = title
        self.motivation = motivation
        self.createdAt = createdAt
        self.walls = walls
    }

    private enum CodingKeys: String, CodingKey { case id, title, motivation, createdAt, walls }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        motivation = try values.decode(String.self, forKey: .motivation)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        // Existing installs have no walls key. Preserve their Builds on upgrade.
        walls = values.contains(.walls) ? try values.decode([Wall].self, forKey: .walls) : []
    }
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
        try persist(updated)
    }

    func createWall(buildID: UUID, title: String) throws {
        guard loadError == nil else { throw SaveError.unavailable }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, cleanTitle.count <= 80 else { throw SaveError.invalidTitle }
        guard let index = builds.firstIndex(where: { $0.id == buildID }) else { throw SaveError.unavailable }
        var updated = builds
        updated[index].walls.append(Wall(id: UUID(), title: cleanTitle, createdAt: Date()))
        try persist(updated)
    }

    func createBrick(buildID: UUID, wallID: UUID, title: String) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { throw SaveError.invalidTitle }
        try updateWall(buildID: buildID, wallID: wallID) { wall in
            wall.bricks.append(Brick(id: UUID(), title: clean, createdAt: Date()))
        }
    }

    func toggleBrick(buildID: UUID, wallID: UUID, brickID: UUID) throws {
        try updateWall(buildID: buildID, wallID: wallID) { wall in
            guard let index = wall.bricks.firstIndex(where: { $0.id == brickID }) else { throw SaveError.unavailable }
            wall.bricks[index].isComplete.toggle()
        }
    }

    func deleteBrick(buildID: UUID, wallID: UUID, brickID: UUID) throws {
        try updateWall(buildID: buildID, wallID: wallID) { wall in
            wall.bricks.removeAll { $0.id == brickID }
        }
    }

    func deleteWall(buildID: UUID, wallID: UUID) throws {
        var updated = builds
        guard let index = updated.firstIndex(where: { $0.id == buildID }) else { throw SaveError.unavailable }
        updated[index].walls.removeAll { $0.id == wallID }
        try persist(updated)
    }

    func deleteBuild(buildID: UUID) throws {
        try persist(builds.filter { $0.id != buildID })
    }

    private func updateWall(buildID: UUID, wallID: UUID, change: (inout Wall) throws -> Void) throws {
        var updated = builds
        guard let b = updated.firstIndex(where: { $0.id == buildID }),
              let w = updated[b].walls.firstIndex(where: { $0.id == wallID }) else { throw SaveError.unavailable }
        try change(&updated[b].walls[w])
        try persist(updated)
    }

    private func persist(_ updated: [Build]) throws {
        guard loadError == nil else { throw SaveError.unavailable }
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
    @ObservedObject var store: BuildStore
    let buildID: UUID
    @State private var showingCreateWall = false
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
                        Label(wall.title, systemImage: "rectangle.split.3x1")
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

struct WallDetailView: View {
    @ObservedObject var store: BuildStore
    let buildID: UUID
    let wallID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreate = false
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
                            do { try store.toggleBrick(buildID: buildID, wallID: wallID, brickID: brick.id) }
                            catch { showingError = true }
                        } label: {
                            Label(brick.title, systemImage: brick.isComplete ? "checkmark.circle.fill" : "circle")
                                .strikethrough(brick.isComplete)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(brick.title)
                        .accessibilityValue(brick.isComplete ? "Complete" : "Incomplete")
                        .accessibilityHint("Double tap to change completion")
                        Spacer()
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

struct CreateBrickView: View {
    @ObservedObject var store: BuildStore
    let buildID: UUID
    let wallID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
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
            }
            .navigationTitle("Add a Brick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        do { try store.createBrick(buildID: buildID, wallID: wallID, title: title); dismiss() }
                        catch { showingError = true }
                    }
                    .disabled(cleanTitle.isEmpty || cleanTitle.count > 80)
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
