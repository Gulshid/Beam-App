import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(SettingsKeys.appearance) private var appearanceRaw = AppAppearance.system.rawValue

    var body: some View {
        Group {
            if appState.isLoadingSession {
                ProgressView()
            } else if appState.currentUser != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.default, value: appState.currentUser)
        .preferredColorScheme((AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
    }
}
