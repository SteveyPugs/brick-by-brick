import SwiftUI

// First native checkpoint: an in-memory UI proof, not persisted user data.
@main
struct BrickByBrickApp: App {
    var body: some Scene {
        WindowGroup {
            WorkbenchView()
        }
    }
}

struct WorkbenchView: View {
    @State private var brickComplete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Meaningful things are built one brick at a time.")
                        .foregroundStyle(.secondary)
                }
                Section("Your first build") {
                    Label("Build a healthier me", systemImage: "square.stack.3d.up")
                    Label("Wall: Build consistency", systemImage: "rectangle.split.3x1")
                    Button {
                        brickComplete.toggle()
                    } label: {
                        Label(
                            brickComplete ? "Brick laid: Take a short walk" : "Brick: Take a short walk",
                            systemImage: brickComplete ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    .accessibilityIdentifier("first-brick")
                    .accessibilityValue(brickComplete ? "Complete" : "Not complete")
                }
                Section {
                    Text("Native iPhone starter · SwiftUI")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color(red: 0.31, green: 0.41, blue: 0.33))
            .navigationTitle("Brick by Brick")
        }
    }
}
