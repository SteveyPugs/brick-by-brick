import XCTest
@testable import BrickByBrick

@MainActor
final class GuidedGoalTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("goals.json")
    }
    func testPersistenceAndSeparateFile() throws {
        let url = temporaryFile()
        let store = GuidedGoalStore(fileURL: url)
        let id = try store.create("Prepare meals")
        try store.update(id) { $0.discovery.append(GoalMessage(isUser: true, text: "Three dinners")); $0.memory = "Three dinners" }
        let restored = GuidedGoalStore(fileURL: url)
        XCTAssertEqual(restored.goal(id)?.memory, "Three dinners")
        XCTAssertEqual(restored.goal(id)?.discovery.last?.text, "Three dinners")
    }
    func testSequentialUnlockRequiresApprovalAndUserOutcome() throws {
        let store = GuidedGoalStore(fileURL: temporaryFile())
        let id = try store.create("A project")
        let first = GoalBrick(title: "Decide", purpose: "Choose a direction", finish: "A direction is agreed")
        let second = GoalBrick(title: "Act", purpose: "Take a step", finish: "Step is done")
        try store.update(id) { $0.bricks = [first, second] }
        XCTAssertFalse(try XCTUnwrap(store.goal(id)).unlocked(0))
        try store.approve(id)
        XCTAssertTrue(try XCTUnwrap(store.goal(id)).unlocked(0))
        XCTAssertThrowsError(try store.complete(id, brickID: second.id, outcome: "Done"))
        XCTAssertThrowsError(try store.complete(id, brickID: first.id, outcome: "  "))
        try store.complete(id, brickID: first.id, outcome: "Chosen a small first step")
        XCTAssertTrue(try XCTUnwrap(store.goal(id)).unlocked(1))
        XCTAssertFalse(try XCTUnwrap(store.goal(id)).unlocked(2))
    }
    func testCorruptStorageIsNotOverwritten() throws {
        let url = temporaryFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("not json".utf8)
        try bytes.write(to: url)
        let store = GuidedGoalStore(fileURL: url)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.create("Do not overwrite"))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testEarlierOutcomesCarryForwardButFutureMessagesDoNot() {
        var first = GoalBrick(title: "Choose", purpose: "Decide", finish: "Decided")
        first.completed = true; first.outcome = "Two dinners and 30 minutes"
        let second = GoalBrick(title: "Prepare", purpose: "Prep", finish: "Prepped")
        var future = GoalBrick(title: "Reflect", purpose: "Review", finish: "Reviewed")
        future.messages = [GoalMessage(isUser: true, text: "FUTURE_SHOULD_NOT_APPEAR")]
        let goal = GuidedGoal(title: "Meals", bricks: [first, second, future], approved: true)
        let context = GuidedGoalAI.context(goal, brick: second)
        XCTAssertTrue(context.contains(first.outcome))
        XCTAssertFalse(context.contains("FUTURE_SHOULD_NOT_APPEAR"))
    }
    func testArchiveRestoresWithoutLosingChat() throws {
        let store = GuidedGoalStore(fileURL: temporaryFile())
        let id = try store.create("Keep this")
        try store.update(id) { $0.archived = true }
        XCTAssertTrue(try XCTUnwrap(store.goal(id)).archived)
        try store.update(id) { $0.archived = false }
        XCTAssertEqual(store.goal(id)?.discovery.count, 1)
    }
}
