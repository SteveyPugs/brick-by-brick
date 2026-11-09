import SwiftUI

@main
struct BrickByBrickApp: App {
    @StateObject private var store = BuildStore()

    var body: some Scene {
        WindowGroup {
            TimelineView(.everyMinute) { context in
                BuildsView(store: store)
                    .environment(\.brickToday, context.date)
                    .tint(BrickStyle.accent)
            }
        }
    }
}

