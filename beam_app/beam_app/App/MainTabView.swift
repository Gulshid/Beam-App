import SwiftUI

/// The app's root, post-login UI: a bottom tab bar with the four top-level screens
/// (Chats, Status, Groups, Settings), mirroring the standard messaging-app layout.
struct MainTabView: View {
    var body: some View {
        TabView {
            ConversationListView()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right")
                }

            StatusView()
                .tabItem {
                    Label("Status", systemImage: "circle.dashed")
                }

            GroupsListView()
                .tabItem {
                    Label("Groups", systemImage: "person.3")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
