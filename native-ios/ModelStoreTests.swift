import XCTest
@testable import BrickByBrick

final class ModelStoreTests: XCTestCase {
    @MainActor
    func testLegacyDataSurvivesRenameAndRelaunch() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("builds.json")
        let b = UUID(), w = UUID(), r = UUID()
        let old: [[String: Any]] = [["id": b.uuidString, "title": "Old Build", "motivation": "Keep me", "createdAt": 0,
            "walls": [["id": w.uuidString, "title": "Old Wall", "createdAt": 0,
                       "bricks": [["id": r.uuidString, "title": "Old Brick", "createdAt": 0, "isComplete": true]]]]]]
        try JSONSerialization.data(withJSONObject: old).write(to: file)
        let store = BuildStore(fileURL: file)
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.builds[0].walls[0].bricks[0].kind, .yesNo)
        try store.rename(buildID: b, title: " Renamed Build ")
        try store.rename(buildID: b, wallID: w, title: "Renamed Wall")
        try store.rename(buildID: b, wallID: w, brickID: r, title: "Renamed Brick")
        let restored = BuildStore(fileURL: file)
        XCTAssertEqual(restored.builds[0].title, "Renamed Build")
        XCTAssertEqual(restored.builds[0].motivation, "Keep me")
        XCTAssertEqual(restored.builds[0].walls[0].title, "Renamed Wall")
        XCTAssertEqual(restored.builds[0].walls[0].bricks[0].id, r)
        XCTAssertEqual(restored.builds[0].walls[0].bricks[0].title, "Renamed Brick")
        XCTAssertTrue(restored.builds[0].walls[0].bricks[0].isComplete)
        let older = [["id": b.uuidString, "title": "Build only", "motivation": "", "createdAt": 0] as [String: Any]]
        let decoded = try JSONDecoder().decode([Build].self, from: JSONSerialization.data(withJSONObject: older))
        XCTAssertTrue(decoded[0].walls.isEmpty)
    }

    @MainActor
    func testMeasuredProgressValidationAndPersistence() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("builds.json")
        let store = BuildStore(fileURL: file)
        try store.create(title: "Goal", motivation: "")
        let b = store.builds[0].id
        try store.createWall(buildID: b, title: "Wall")
        let w = store.builds[0].walls[0].id
        try store.createBrick(buildID: b, wallID: w, title: "Water", kind: .count, target: 8, unit: "glasses")
        let r = store.builds[0].walls[0].bricks[0].id
        XCTAssertThrowsError(try store.recordProgress(buildID: b, wallID: w, brickID: r, value: 1.5))
        XCTAssertThrowsError(try store.recordProgress(buildID: b, wallID: w, brickID: r, value: -1))
        XCTAssertThrowsError(try store.recordProgress(buildID: b, wallID: w, brickID: r, value: .infinity))
        XCTAssertThrowsError(try store.createBrick(buildID: b, wallID: w, title: "Bad", kind: .amount, target: 0, unit: "miles"))
        XCTAssertThrowsError(try store.createBrick(buildID: b, wallID: w, title: "Bad", kind: .count, target: 1.5, unit: "items"))
        try store.recordProgress(buildID: b, wallID: w, brickID: r, value: 5)
        XCTAssertFalse(store.builds[0].walls[0].bricks[0].isComplete)
        try store.recordProgress(buildID: b, wallID: w, brickID: r, value: 9)
        XCTAssertTrue(store.builds[0].walls[0].bricks[0].isComplete)
        try store.recordProgress(buildID: b, wallID: w, brickID: r, value: 3)
        try store.createBrick(buildID: b, wallID: w, title: "Walk", kind: .amount, target: 2.5, unit: "miles")
        let a = store.builds[0].walls[0].bricks[1].id
        try store.recordProgress(buildID: b, wallID: w, brickID: a, value: 2.5)
        let restored = BuildStore(fileURL: file)
        let bricks = restored.builds[0].walls[0].bricks
        XCTAssertEqual(bricks[0].progress, 3)
        XCTAssertFalse(bricks[0].isComplete)
        XCTAssertEqual(bricks[1].progress, 2.5)
        XCTAssertTrue(bricks[1].isComplete)
        XCTAssertNil(NumberInput.parse("NaN"))
        XCTAssertNil(NumberInput.parse("-1"))
        XCTAssertNil(NumberInput.parse(""))
        XCTAssertFalse(NumberInput.validTarget(kind: .count, target: "1.5", unit: "items"))
        XCTAssertTrue(NumberInput.validTarget(kind: .amount, target: "1.5", unit: "miles"))
    }

    @MainActor
    func testDemoPlanAndCorruptDataProtection() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("builds.json")
        let store = BuildStore(fileURL: file)
        let drafts = DemoPlanner.suggest(goal: "Read more books")
        XCTAssertEqual(drafts.count, 2)
        XCTAssertTrue(drafts.allSatisfy { $0.valid })
        XCTAssertTrue(store.builds.isEmpty) // Preview is not a save.
        let plan = Build(id: UUID(), title: "Reading", motivation: "Read more books", createdAt: Date(), walls: drafts.map {
            Wall(id: UUID(), title: $0.title, createdAt: Date(), bricks: $0.bricks.map { $0.brick })
        })
        try store.savePlan(plan)
        XCTAssertEqual(BuildStore(fileURL: file).builds[0].walls.flatMap { $0.bricks }.count, 4)
        let corrupt = Data("not valid saved data".utf8)
        try corrupt.write(to: file)
        let broken = BuildStore(fileURL: file)
        XCTAssertNotNil(broken.loadError)
        XCTAssertThrowsError(try broken.savePlan(plan))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
}
