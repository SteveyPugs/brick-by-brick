import SwiftUI

@MainActor
final class BuildStore: ObservableObject {
    @Published private(set) var builds: [Build] = []
    @Published private(set) var loadError: String?
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrickByBrick", isDirectory: true)
        self.fileURL = fileURL ?? folder.appendingPathComponent("builds-v1.json")
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

    func createBrick(buildID: UUID, wallID: UUID, title: String, kind: BrickKind = .yesNo, target: Double = 1, unit: String = "", repeatDays: Set<BrickWeekday> = []) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { throw SaveError.invalidTitle }
        try validateMeasurement(kind: kind, target: target, unit: unit)
        try updateWall(buildID: buildID, wallID: wallID) { wall in
            wall.bricks.append(Brick(title: clean, kind: kind, target: target, unit: unit.trimmingCharacters(in: .whitespacesAndNewlines), repeatDays: repeatDays))
        }
    }

    func toggleBrick(buildID: UUID, wallID: UUID, brickID: UUID, on date: Date = .now,
                     calendar: Calendar = BrickWeekday.localCalendar()) throws {
        try updateWall(buildID: buildID, wallID: wallID) { wall in
            guard let index = wall.bricks.firstIndex(where: { $0.id == brickID }) else { throw SaveError.unavailable }
            guard wall.bricks[index].kind == .yesNo else { throw SaveError.unavailable }
            guard wall.bricks[index].isDue(on: date, calendar: calendar) else { throw SaveError.unavailable }
            if wall.bricks[index].repeatDays.isEmpty {
                wall.bricks[index].isComplete.toggle()
            } else {
                let complete = wall.bricks[index].occurrence(on: date, calendar: calendar).isComplete
                wall.bricks[index].setOccurrence(complete ? 0 : 1, on: date, calendar: calendar)
            }
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

    func rename(buildID: UUID, wallID: UUID? = nil, brickID: UUID? = nil, title: String) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80 else { throw SaveError.invalidTitle }
        var updated = builds
        guard let b = updated.firstIndex(where: { $0.id == buildID }) else { throw SaveError.unavailable }
        if let wallID = wallID {
            guard let w = updated[b].walls.firstIndex(where: { $0.id == wallID }) else { throw SaveError.unavailable }
            if let brickID = brickID {
                guard let r = updated[b].walls[w].bricks.firstIndex(where: { $0.id == brickID }) else { throw SaveError.unavailable }
                updated[b].walls[w].bricks[r].title = clean
            } else { updated[b].walls[w].title = clean }
        } else { updated[b].title = clean }
        try persist(updated)
    }

    func recordProgress(buildID: UUID, wallID: UUID, brickID: UUID, value: Double,
                        on date: Date = .now, calendar: Calendar = BrickWeekday.localCalendar()) throws {
        try updateWall(buildID: buildID, wallID: wallID) { wall in
            guard let r = wall.bricks.firstIndex(where: { $0.id == brickID }) else { throw SaveError.unavailable }
            let kind = wall.bricks[r].kind
            guard kind != .yesNo, value.isFinite, value >= 0, value <= 1_000_000_000,
                  kind != .count || value.rounded() == value else { throw SaveError.invalidTitle }
            guard wall.bricks[r].isDue(on: date, calendar: calendar) else { throw SaveError.unavailable }
            if wall.bricks[r].repeatDays.isEmpty {
                wall.bricks[r].progress = value
                wall.bricks[r].isComplete = value >= wall.bricks[r].target
            } else {
                wall.bricks[r].setOccurrence(value, on: date, calendar: calendar)
            }
        }
    }

    func validateMeasurement(kind: BrickKind, target: Double, unit: String) throws {
        guard kind == .yesNo || (target.isFinite && target > 0 && target <= 1_000_000_000 &&
              (kind != .count || target.rounded() == target) &&
              !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unit.count <= 30) else { throw SaveError.invalidTitle }
    }

    func savePlan(_ build: Build) throws {
        guard !build.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, build.title.count <= 80,
              !build.walls.isEmpty else { throw SaveError.invalidTitle }
        for wall in build.walls {
            guard !wall.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, wall.title.count <= 80 else { throw SaveError.invalidTitle }
            for brick in wall.bricks {
                guard !brick.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, brick.title.count <= 80 else { throw SaveError.invalidTitle }
                try validateMeasurement(kind: brick.kind, target: brick.target, unit: brick.unit)
            }
        }
        try persist([build] + builds)
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

