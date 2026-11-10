import Foundation
import Combine

struct GoalMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var isUser: Bool
    var text: String
}

struct GoalBrick: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var purpose: String
    var finish: String
    var messages: [GoalMessage] = []
    var memory = ""
    var outcome = ""
    var completed = false
    // Optional fields preserve decoding of goals created by earlier builds.
    var readiness: String? = nil
    var proposedOutcome: String? = nil
    var canReviewCompletion: Bool {
        !completed && readiness == "ready_to_wrap" &&
        !(proposedOutcome ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        messages.last?.isUser == false
    }
}

struct GuidedGoal: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var discovery: [GoalMessage] = []
    var memory = ""
    var bricks: [GoalBrick] = []
    var approved = false
    var archived = false
    var nextIndex: Int? { bricks.firstIndex { !$0.completed } }
    func unlocked(_ index: Int) -> Bool {
        approved && bricks.indices.contains(index) && bricks.prefix(index).allSatisfy(\.completed)
    }
}

@MainActor
final class GuidedGoalStore: ObservableObject {
    @Published private(set) var goals: [GuidedGoal] = []
    @Published private(set) var loadError: String?
    private let fileURL: URL
    enum StoreError: LocalizedError {
        case unavailable, invalid, locked
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Saved goals could not be opened. Your file has not been changed."
            case .invalid: return "Please add a goal, a valid plan, or a short completion note before continuing."
            case .locked: return "Complete the earlier bricks first."
            }
        }
    }
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrickByBrick/guided-goals-v1.json")
        load()
    }
    func load() {
        do {
            let data: Data
            do { data = try Data(contentsOf: fileURL) }
            catch CocoaError.fileReadNoSuchFile { goals = []; loadError = nil; return }
            goals = try JSONDecoder().decode([GuidedGoal].self, from: data)
            loadError = nil
        } catch { loadError = StoreError.unavailable.localizedDescription }
    }
    func goal(_ id: UUID) -> GuidedGoal? { goals.first { $0.id == id } }
    @discardableResult func create(_ title: String) throws -> UUID {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 300 else { throw StoreError.invalid }
        let goal = GuidedGoal(title: clean, discovery: [GoalMessage(isUser: false,
            text: "What would success look like for you, and what should I know about your starting point? You can answer in your own words.")])
        try persist([goal] + goals)
        return goal.id
    }
    func update(_ id: UUID, _ edit: (inout GuidedGoal) throws -> Void) throws {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { throw StoreError.unavailable }
        var copy = goals
        try edit(&copy[index])
        try persist(copy)
    }
    func approve(_ id: UUID) throws {
        try update(id) { goal in
            guard !goal.bricks.isEmpty, goal.bricks.allSatisfy({ !$0.title.isEmpty && !$0.finish.isEmpty }) else { throw StoreError.invalid }
            goal.approved = true
        }
    }
    func complete(_ id: UUID, brickID: UUID, outcome: String) throws {
        let clean = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 1200 else { throw StoreError.invalid }
        try update(id) { goal in
            guard let i = goal.bricks.firstIndex(where: { $0.id == brickID }), goal.unlocked(i) else { throw StoreError.locked }
            goal.bricks[i].outcome = clean
            goal.bricks[i].completed = true
        }
    }
    private func persist(_ copy: [GuidedGoal]) throws {
        guard loadError == nil else { throw StoreError.unavailable }
        let data = try JSONEncoder().encode(copy)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        goals = copy
    }
}
