import SwiftUI

@main
struct M88CardsApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .tint(.blue)
        }
    }
}
