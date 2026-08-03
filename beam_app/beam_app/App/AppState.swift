import Foundation
import FirebaseAuth
import Combine

/// Single source of truth for "am I logged in, and as whom".
/// ViewModels read this instead of talking to FirebaseAuth directly,
/// so nothing outside this class imports FirebaseAuth.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isLoadingSession = true

    private var authHandle: AuthStateDidChangeListenerHandle?
    private let userRepository: UserRepository

    init(userRepository: UserRepository = FirestoreUserRepository()) {
        self.userRepository = userRepository
        observeAuthState()
    }

    private func observeAuthState() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task { @MainActor in
                await self.handle(firebaseUser: firebaseUser)
            }
        }
    }

    private func handle(firebaseUser: FirebaseAuth.User?) async {
        defer { isLoadingSession = false }

        guard let firebaseUser else {
            currentUser = nil
            return
        }

        do {
            currentUser = try await userRepository.fetchOrCreateUser(
                uid: firebaseUser.uid,
                displayName: firebaseUser.displayName ?? "User",
                email: firebaseUser.email
            )
        } catch {
            print("AppState: failed to load user profile — \(error)")
            currentUser = nil
        }
    }

    /// Re-fetches the current user's Firestore profile and republishes it.
    /// Useful right after an out-of-band write (e.g. correcting displayName
    /// post-signup) that the auth-state listener won't automatically pick up.
    func refreshCurrentUser() async {
        guard let uid = currentUser?.id else { return }
        if let refreshed = try? await userRepository.fetchUser(uid: uid) {
            currentUser = refreshed
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        currentUser = nil
    }

    /// Deletes the signed-in user's FirebaseAuth account and their Firestore profile
    /// document. FirebaseAuth requires a "recent" sign-in for this; if that's not the
    /// case it throws `.requiresRecentLogin`, which callers should surface as
    /// "please sign out and sign back in, then try again" rather than a generic error.
    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let uid = firebaseUser.uid
        try await firebaseUser.delete()
        try? await userRepository.deleteUserProfile(uid: uid)
        currentUser = nil
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }
}
