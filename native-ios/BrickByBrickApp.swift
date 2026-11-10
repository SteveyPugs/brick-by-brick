import SwiftUI

@main
struct BrickByBrickApp: App {
    @StateObject private var store = BuildStore()
    @StateObject private var guidedStore = GuidedGoalStore()
    @State private var today = Date.now
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                BuildsView(store: store)
                    .tabItem { Label("My Walls", systemImage: "square.stack.3d.up") }
                GuidedGoalsView(store: guidedStore)
                    .tabItem { Label("Guided Goals", systemImage: "sparkles") }
            }
                .environment(\.brickToday, today)
                .tint(BrickStyle.accent)
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        let now = Date.now
                        if !BrickWeekday.localCalendar().isDate(today, inSameDayAs: now) { today = now }
                        try? await Task.sleep(for: .seconds(15))
                    }
                }
        }
    }
}

