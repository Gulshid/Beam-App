import SwiftUI

/// The app's root, post-login UI: the four top-level screens (Chats, Status,
/// Groups, Settings) hosted in a `TabView` whose native chrome is hidden in
/// favor of `CustomTabBar` — a floating, glass-material bar with a sliding
/// selection pill and a live unread badge. `TabView` still owns tab switching
/// and per-tab state underneath; only the visuals are replaced.
struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var unreadBadgeStore = UnreadBadgeStore()
    @State private var selectedTab: AppTab = .chats

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView()
                .tag(AppTab.chats)

            StatusView()
                .tag(AppTab.status)

            GroupsListView()
                .tag(AppTab.groups)

            SettingsView()
                .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selection: $selectedTab, unreadCount: unreadBadgeStore.totalUnreadCount)
                .padding(.bottom, 6)
        }
        .environmentObject(unreadBadgeStore)
        .task(id: appState.currentUser?.id) {
            if let uid = appState.currentUser?.id {
                unreadBadgeStore.start(currentUserId: uid)
            }
        }
        .onDisappear { unreadBadgeStore.stop() }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
