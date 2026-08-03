import Foundation
import UserNotifications

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isDeletingAccount = false
    @Published var isClearingCache = false
    @Published var errorMessage: String?
    @Published var didClearCache = false

    /// Removes every locally-cached conversation/message. Firestore listeners refill
    /// everything the next time each chat is opened, so this only reclaims disk space —
    /// it never touches server data.
    func clearLocalCache() async {
        isClearingCache = true
        defer { isClearingCache = false }
        await SwiftDataStore.shared.clearAllCache()
        didClearCache = true
    }

    /// Deletes the account via `AppState`. Surfaces FirebaseAuth's "requires recent
    /// login" error with actionable copy, since that's the one failure mode a user
    /// can actually resolve themselves (sign out, sign back in, try again).
    func deleteAccount(appState: AppState) async -> Bool {
        errorMessage = nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await appState.deleteAccount()
            return true
        } catch {
            let nsError = error as NSError
            if nsError.domain == "FIRAuthErrorDomain", nsError.code == 17014 {
                errorMessage = "For security, please sign out and sign back in, then try deleting your account again."
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    /// Requests OS-level push permission the first time the user flips the
    /// notifications toggle on. If they deny it, we leave the toggle in whatever
    /// state the OS actually granted rather than lying about it.
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
