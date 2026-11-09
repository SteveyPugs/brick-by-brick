import SwiftUI

@main
struct BrickByBrickApp: App {
    @StateObject private var store = BuildStore()

    var body: some Scene {
        WindowGroup {
            BuildsView(store: store)
                .tint(Color(red: 0.31, green: 0.41, blue: 0.33))
        }
    }
}

