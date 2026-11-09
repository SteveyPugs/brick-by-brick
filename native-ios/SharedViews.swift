import SwiftUI

enum NumberInput {
    static func parse(_ text: String) -> Double? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let separator = Locale.current.decimalSeparator ?? "."
        let normalized = separator == "." ? clean : clean.replacingOccurrences(of: separator, with: ".")
        guard normalized.range(of: "^[0-9]+(\\.[0-9]+)?$", options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
    static func editable(_ value: Double) -> String {
        String(value).replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }
    static func validTarget(kind: BrickKind, target: String, unit: String) -> Bool {
        if kind == .yesNo { return true }
        guard let value = parse(target), value > 0, value <= 1_000_000_000,
              kind != .count || value.rounded() == value else { return false }
        return !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unit.count <= 30
    }
}

struct CompletionSummary: View {
    let bricks: [Brick]
    var body: some View {
        Text("\(bricks.filter { $0.isComplete }.count) of \(bricks.count) Bricks complete")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct MeasurementFields: View {
    @Binding var kind: BrickKind
    @Binding var target: String
    @Binding var unit: String
    var body: some View {
        Section {
            Picker("Brick type", selection: $kind) {
                ForEach(BrickKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented).accessibilityIdentifier("brick-type")
            if kind != .yesNo {
                TextField("Target", text: $target).keyboardType(.decimalPad)
                    .accessibilityIdentifier("brick-target")
                TextField("Unit, e.g. glasses or minutes", text: $unit)
                    .accessibilityIdentifier("brick-unit")
            }
        } header: { Text("How to measure it") }
          footer: {
            Text(kind == .yesNo ? "Check it off when done. No automatic daily reset." :
                 "Use a positive target (up to 1 billion) and a unit (up to 30 characters). Counts use whole numbers; amounts allow decimals. No automatic daily reset.")
        }
    }
}

struct NameEditor: View {
    @State var title: String
    let heading: String
    let save: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var failed = false
    private var clean: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $title).accessibilityIdentifier("edit-name")
                } footer: { Text("Use 1–80 characters. Renaming keeps your progress and everything inside.") }
            }
            .navigationTitle(heading).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { do { try save(clean); dismiss() } catch { failed = true } }
                        .disabled(clean.isEmpty || clean.count > 80).accessibilityIdentifier("save-name")
                }
            }
            .interactiveDismissDisabled()
            .alert("Name wasn’t saved", isPresented: $failed) { Button("OK", role: .cancel) {} }
                message: { Text("Your draft is still here. Please try again.") }
        }
    }
}

struct ProgressEditor: View {
    let brick: Brick
    let save: (Double) throws -> Void
    @State private var value: String
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss
    init(brick: Brick, save: @escaping (Double) throws -> Void) {
        self.brick = brick; self.save = save
        _value = State(initialValue: NumberInput.editable(brick.progress))
    }
    private var valid: Bool {
        guard let n = NumberInput.parse(value), n <= 1_000_000_000 else { return false }
        return brick.kind != .count || n.rounded() == n
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(brick.title).font(.headline)
                    Text("Target: \(brick.target.formatted()) \(brick.unit)")
                    TextField("Current total", text: $value).keyboardType(.decimalPad)
                        .accessibilityIdentifier("progress-value")
                } footer: {
                    Text("Enter your current total, not an amount to add. Reaching the target completes this Brick. A lower total marks it incomplete again. Use zero to reset.")
                }
            }
            .navigationTitle("Record progress").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let n = NumberInput.parse(value), valid else { return }
                        do { try save(n); dismiss() } catch { failed = true }
                    }.disabled(!valid).accessibilityIdentifier("save-progress")
                }
            }
            .interactiveDismissDisabled()
            .alert("Progress wasn’t saved", isPresented: $failed) { Button("OK", role: .cancel) {} }
                message: { Text("Your saved progress hasn’t changed. Please try again.") }
        }
    }
}
