import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(SettingsKeys.appearance) private var appearanceRaw = AppAppearance.system.rawValue

    private static let minimumSplashDuration: TimeInterval = 2.2

    @State private var minimumDurationElapsed = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if appState.isLoadingSession {
                    Color.clear
                } else if appState.currentUser != nil {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .animation(.default, value: appState.currentUser)

            if showSplash {
                SplashScreenView(isActive: showSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme((AppAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(Self.minimumSplashDuration * 1_000_000_000))
            minimumDurationElapsed = true
            dismissSplashIfReady()
        }
        .onChange(of: appState.isLoadingSession) { _, _ in
            dismissSplashIfReady()
        }
    }

    private func dismissSplashIfReady() {
        guard minimumDurationElapsed, !appState.isLoadingSession, showSplash else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            showSplash = false
        }
    }
}
