import Foundation

/// Shared with every tab's content via `.environmentObject` from `MainTabView`.
///
/// `CustomTabBar` is attached to the *outer* `TabView` as a `safeAreaInset`,
/// so by default it stays floating above whatever is currently pushed inside
/// a tab's `NavigationStack` — including a chat's own bottom-anchored
/// composer, which it would otherwise sit on top of. Screens that own
/// full-width, bottom-anchored UI of their own (chiefly `ChatView`'s message
/// field) flip `isHidden` to `true` while they're on screen so the composer
/// gets the full screen height, then flip it back on the way out.
@MainActor
final class TabBarVisibility: ObservableObject {
    @Published var isHidden = false
}
