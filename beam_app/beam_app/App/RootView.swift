import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isLoadingSession {
                ProgressView()
            } else if appState.currentUser != nil {
                ConversationListView()
            } else {
                LoginView()
            }
        }
        .animation(.default, value: appState.currentUser)
    }
}
