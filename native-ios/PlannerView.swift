import SwiftUI

struct PlanBrickDraft: Identifiable {
    let id = UUID()
    var title: String
    var kind: BrickKind = .yesNo
    var target = "1"
    var unit = ""
    var valid: Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.count <= 80 && NumberInput.validTarget(kind: kind, target: target, unit: unit)
    }
    var brick: Brick {
        Brick(title: title.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind,
              target: kind == .yesNo ? 1 : NumberInput.parse(target) ?? 1,
              unit: kind == .yesNo ? "" : unit.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct PlanWallDraft: Identifiable {
    let id = UUID()
    var title: String
    var bricks: [PlanBrickDraft]
    var valid: Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.count <= 80 && !bricks.isEmpty && bricks.allSatisfy { $0.valid }
    }
}

// Deliberately deterministic local examples. No AI service or network calls.
enum DemoPlanner {
    static func suggest(goal: String) -> [PlanWallDraft] {
        let reading = goal.lowercased().contains("read") || goal.lowercased().contains("book")
        return [
            PlanWallDraft(title: reading ? "Make space for reading" : "Get ready", bricks: [
                PlanBrickDraft(title: reading ? "Choose a book" : "Choose a first step"),
                PlanBrickDraft(title: "Write down why this matters")
            ]),
            PlanWallDraft(title: reading ? "Spend time reading" : "Take small steps", bricks: [
                PlanBrickDraft(title: reading ? "Read for a little while" : "Focused practice", kind: .amount, target: "20", unit: "minutes"),
                PlanBrickDraft(title: reading ? "Read a few pages" : "Try three small actions", kind: .amount, target: "3", unit: reading ? "pages" : "actions")
            ])
        ]
    }
}

struct PlannerView: View {
    @ObservedObject var store: BuildStore
    @Environment(\.dismiss) private var dismiss
    @State private var goal = ""
    @State private var title = ""
    @State private var walls: [PlanWallDraft] = []
    @State private var reviewing = false
    @State private var failed = false
    private var cleanGoal: String { goal.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var valid: Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.count <= 80 && !walls.isEmpty && walls.allSatisfy { $0.valid }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Demo — not live AI", systemImage: "sparkles").font(.headline)
                    Text("These are editable sample suggestions, not an LLM response. Nothing leaves this device or is saved until you choose Save plan.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !reviewing {
                    Section("What would you like to build?") {
                        TextField("Describe your goal", text: $goal, axis: .vertical)
                            .lineLimit(3...6).accessibilityIdentifier("planner-goal")
                        Button("Show sample plan") {
                            title = String(cleanGoal.prefix(80))
                            walls = DemoPlanner.suggest(goal: cleanGoal)
                            reviewing = true
                        }
                        .disabled(cleanGoal.isEmpty || cleanGoal.count > 500)
                        .accessibilityIdentifier("suggest-plan")
                        Text("Up to 500 characters. Reading goals get a reading example; other goals get a general starter template.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Review your Build") {
                        TextField("Build name", text: $title).accessibilityIdentifier("plan-title")
                        Text("Edit the names below. Open a Brick to adjust its type, target, and unit. These are one-time actions, not a recurring schedule.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach($walls) { $wall in
                        Section {
                            TextField("Wall name", text: $wall.title)
                                .accessibilityLabel("Suggested Wall name")
                            ForEach($wall.bricks) { $brick in
                                NavigationLink {
                                    PlanBrickEditor(draft: $brick)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(brick.title)
                                        Text(brick.kind == .yesNo ? "Check off" : "\(brick.target) \(brick.unit)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: { Text("Suggested Wall") }
                    }
                    Section {
                        Text("Names need 1–80 characters. Fix any invalid names or targets before saving.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Save plan") { savePlan() }
                            .disabled(!valid).accessibilityIdentifier("save-plan")
                    }
                }
            }
            .navigationTitle("Help me build this").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .interactiveDismissDisabled(!goal.isEmpty)
            .alert("Plan wasn’t saved", isPresented: $failed) { Button("OK", role: .cancel) {} }
                message: { Text("Your draft is still here. Please try again.") }
        }
    }
    private func savePlan() {
        guard valid else { return }
        let build = Build(id: UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                          motivation: cleanGoal, createdAt: Date(), walls: walls.map {
            Wall(id: UUID(), title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                 createdAt: Date(), bricks: $0.bricks.map { $0.brick })
        })
        do { try store.savePlan(build); dismiss() } catch { failed = true }
    }
}

struct PlanBrickEditor: View {
    @Binding var draft: PlanBrickDraft
    var body: some View {
        Form {
            Section("Brick name") {
                TextField("Brick name", text: $draft.title).accessibilityIdentifier("plan-brick-name")
            }
            MeasurementFields(kind: $draft.kind, target: $draft.target, unit: $draft.unit)
            Text("These changes are only in your draft. Return to the plan to save everything together.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle("Edit suggestion").navigationBarTitleDisplayMode(.inline)
    }
}
