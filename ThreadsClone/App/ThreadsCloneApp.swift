import SwiftUI

@main
struct ThreadsCloneApp: App {
    @State private var store: ThreadsStore
    private let defaults: UserDefaults

    init() {
        // An optional suite isolates UI automation and preview sessions from personal local data.
        let suite = ProcessInfo.processInfo.environment["THREADS_STORAGE_SUITE"]
        let defaults = suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.defaults = defaults
        _store = State(initialValue: ThreadsStore(defaults: defaults))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .defaultAppStorage(defaults)
                .preferredColorScheme(.dark)
                .tint(ThreadTheme.white)
        }
    }
}
