import SwiftUI

@main
struct BrickByBrickApp: App {
    @StateObject private var store = BuildStore()
    @State private var today = Date.now
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BuildsView(store: store)
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

