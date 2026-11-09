import SwiftUI

struct PlanBrickDraft: Identifiable {
    let id = UUID()
    var title: String
    var kind: BrickKind = .yesNo
    var target = "1"
    var unit = ""
    var repeatDays: Set<BrickWeekday> = []
    var valid: Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.count <= 80 && NumberInput.validTarget(kind: kind, target: target, unit: unit)
    }
    var brick: Brick {
        Brick(title: title.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind,
              target: kind == .yesNo ? 1 : NumberInput.parse(target) ?? 1,
              unit: kind == .yesNo ? "" : unit.trimmingCharacters(in: .whitespacesAndNewlines),
              repeatDays: repeatDays)
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

struct PlannerView: View {
    @ObservedObject var store: BuildStore
    @Environment(\.dismiss) private var dismiss
    @State private var goal = ""
    @State private var title = ""
    @State private var followUp = ""
    @State private var walls: [PlanWallDraft] = []
    @State private var askingFollowUp = false
    @State private var reviewing = false
    @State private var failed = false
    @State private var generatedWithAI = false
    @State private var generation: Task<Void, Never>?
    @State private var generationFailed = false
    private var cleanGoal: String { goal.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanFollowUp: String { followUp.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var valid: Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.count <= 80 && !walls.isEmpty && walls.allSatisfy { $0.valid }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(reviewing ? (generatedWithAI ? "On-device AI draft" : "Starter draft — no AI") : "Build a plan you can start", systemImage: "sparkles").font(.headline)
                    Text("Your goal stays on this device. Nothing is saved until you choose Save plan.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if !reviewing && !askingFollowUp {
                    Section("What would you like to build?") {
                        TextField("Describe your goal", text: $goal, axis: .vertical)
                            .lineLimit(3...6).accessibilityIdentifier("planner-goal")
                        Button("Continue") { askingFollowUp = true }
                        .disabled(cleanGoal.isEmpty || cleanGoal.count > 500)
                        .accessibilityIdentifier("planner-continue")
                        Text("Up to 500 characters. A goal like “read more” or “practice guitar” is enough to start.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if !reviewing {
                    Section("What feels realistic on a busy week?") {
                        TextField("e.g. 10 minutes on Monday, Wednesday and Friday", text: $followUp, axis: .vertical)
                            .lineLimit(2...4).accessibilityIdentifier("planner-follow-up")
                        Text("Optional. Add a time budget, preferred days, or something that usually gets in the way.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section {
                        if PlanGenerator.isAvailable {
                            Button("Draft with Apple Intelligence") { generate() }
                                .disabled(generation != nil || cleanFollowUp.count > 300)
                                .accessibilityIdentifier("suggest-plan")
                        } else {
                            Text("Apple Intelligence isn’t available right now. You can still start with an editable draft.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Button("Use a starter draft") {
                            review(PlanGenerator.starter(goal: cleanGoal, details: cleanFollowUp), ai: false)
                        }
                        .disabled(generation != nil || cleanFollowUp.count > 300)
                        .accessibilityIdentifier("planner-starter")
                        if generation != nil { ProgressView("Drafting your plan…") }
                        Button("Back to goal") { askingFollowUp = false }.disabled(generation != nil)
                    }
                } else {
                    Section("Review your Build") {
                        TextField("Build name", text: $title).accessibilityIdentifier("plan-title")
                        Text("Edit or remove anything that doesn’t fit. Open a Brick to change its target, unit, or schedule.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach($walls) { $wall in
                        Section {
                            TextField("Wall name", text: $wall.title)
                                .accessibilityLabel("Suggested Wall name")
                            ForEach($wall.bricks) { $brick in
                                let brickID = brick.id
                                NavigationLink {
                                    PlanBrickEditor(draft: $brick)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(brick.title)
                                        Text(brick.kind == .yesNo ? "Check off" : "\(brick.target) \(brick.unit)")
                                            .font(.caption).foregroundStyle(.secondary)
                                        if !brick.repeatDays.isEmpty {
                                            Text(brick.brick.repeatLabel).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Button("Remove \(brick.title)", role: .destructive) {
                                    wall.bricks.removeAll { $0.id == brickID }
                                }
                            }
                            Button("Add a Brick") { wall.bricks.append(PlanBrickDraft(title: "")) }
                            Button("Remove Wall", role: .destructive) { walls.removeAll { $0.id == wall.id } }
                        } header: { Text("Suggested Wall") }
                    }
                    Section {
                        Button("Add a Wall") { walls.append(PlanWallDraft(title: "", bricks: [])) }
                        Text("Give each Wall at least one Brick. Fix any empty names or invalid targets before saving.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Help me build this").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { generation?.cancel(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if reviewing {
                        Button("Save plan") { savePlan() }
                            .disabled(!valid).accessibilityIdentifier("save-plan")
                    }
                }
            }
            .interactiveDismissDisabled(!goal.isEmpty)
            .alert("Plan wasn’t saved", isPresented: $failed) { Button("OK", role: .cancel) {} }
                message: { Text("Your draft is still here. Please try again.") }
            .alert("Couldn’t draft with Apple Intelligence", isPresented: $generationFailed) {
                Button("OK", role: .cancel) {}
            } message: { Text("Try again, simplify your goal, or use a starter draft.") }
        }
    }
    private func review(_ draft: [PlanWallDraft], ai: Bool) {
        title = String(cleanGoal.prefix(80))
        walls = draft
        generatedWithAI = ai
        reviewing = true
    }
    private func generate() {
        let input = cleanGoal, details = cleanFollowUp
        generation = Task { @MainActor in
            defer { generation = nil }
            do {
                let draft = try await PlanGenerator.suggest(goal: input, details: details)
                guard !Task.isCancelled else { return }
                review(draft, ai: true)
            } catch {
                if !Task.isCancelled { generationFailed = true }
            }
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
            RepeatFields(days: $draft.repeatDays)
            Text("These changes are only in your draft. Return to the plan to save everything together.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle("Edit suggestion").navigationBarTitleDisplayMode(.inline)
    }
}
