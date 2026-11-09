import SwiftUI

enum BrickStyle {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.62, blue: 0.48, alpha: 1)
            : UIColor(red: 0.61, green: 0.27, blue: 0.19, alpha: 1)
    })
}

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
    private let suggestedUnits = ["minutes", "pages", "reps", "miles", "steps", "glasses"]
    private var tracking: Binding<Bool> {
        Binding(get: { kind != .yesNo }, set: { enabled in
            if enabled != (kind != .yesNo) { kind = enabled ? .amount : .yesNo }
        })
    }
    var body: some View {
        Section {
            Picker("Brick type", selection: tracking) {
                Text("Check off").tag(false)
                Text("Track progress").tag(true)
            }
            .pickerStyle(.segmented).accessibilityIdentifier("brick-type")
            if kind != .yesNo {
                TextField("Target", text: $target).keyboardType(.decimalPad)
                    .accessibilityIdentifier("brick-target")
                TextField("Unit or custom unit", text: $unit)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("brick-unit")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested units").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), alignment: .leading)],
                              alignment: .leading, spacing: 6) {
                        ForEach(suggestedUnits, id: \.self) { suggestion in
                            Button {
                                unit = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .padding(.horizontal, 6)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(BrickStyle.accent.opacity(unit == suggestion ? 0.20 : 0.08),
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityAddTraits(unit == suggestion ? .isSelected : [])
                            .accessibilityIdentifier("brick-unit-\(suggestion)")
                        }
                    }
                }
            }
        } header: { Text("How to measure it") }
          footer: {
            Text(kind == .yesNo ? "Check it off when done. No automatic daily reset." :
                 kind == .count ? "This Brick uses whole numbers. Choose a suggestion or enter your own unit." :
                 "Use a whole number or a decimal, like 20 pages or 2.5 miles. No automatic daily reset.")
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
