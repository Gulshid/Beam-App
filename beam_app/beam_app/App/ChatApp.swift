import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct ChatApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()

        // Firestore's own on-disk cache: queues writes made while offline and replays
        // them once connectivity returns, and serves reads from cache instantly in the
        // meantime. This sits *alongside* the SwiftData cache in Core/Persistence, not
        // instead of it — Firestore's cache is opaque/unqueryable, SwiftData is what the
        // UI actually reads on cold launch, before any listener has reconnected.
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
