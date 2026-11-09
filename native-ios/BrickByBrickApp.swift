import SwiftUI

@main
struct BrickByBrickApp: App {
    @StateObject private var store = BuildStore()

    var body: some Scene {
        WindowGroup {
            BuildsView(store: store)
                .tint(BrickStyle.accent)
        }
    }
}

