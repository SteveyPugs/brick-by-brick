import Foundation

enum BrickKind: String, Codable {
    // Keep the original count encoding and whole-number rule for saved Bricks.
    // New tracked Bricks use amount, which accepts whole numbers and decimals.
    case yesNo, count, amount
}

struct Brick: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var isComplete: Bool = false
    var kind: BrickKind = .yesNo
    var target: Double = 1
    var unit: String = ""
    var progress: Double = 0

    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), isComplete: Bool = false,
         kind: BrickKind = .yesNo, target: Double = 1, unit: String = "", progress: Double = 0) {
        self.id = id; self.title = title; self.createdAt = createdAt
        self.kind = kind; self.target = target; self.unit = unit; self.progress = progress
        self.isComplete = kind == .yesNo ? isComplete : progress >= target
    }
    private enum CodingKeys: String, CodingKey { case id, title, createdAt, isComplete, kind, target, unit, progress }
    init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        id = try v.decode(UUID.self, forKey: .id)
        title = try v.decode(String.self, forKey: .title)
        createdAt = try v.decode(Date.self, forKey: .createdAt)
        kind = try v.decodeIfPresent(BrickKind.self, forKey: .kind) ?? .yesNo
        target = try v.decodeIfPresent(Double.self, forKey: .target) ?? 1
        unit = try v.decodeIfPresent(String.self, forKey: .unit) ?? ""
        progress = try v.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        isComplete = try v.decode(Bool.self, forKey: .isComplete)
        if kind != .yesNo { isComplete = progress >= target }
    }
    var progressLabel: String { "\(progress.formatted()) of \(target.formatted()) \(unit)" }
}

struct Wall: Identifiable, Codable {
    let id: UUID
    var title: String
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
    var title: String
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

