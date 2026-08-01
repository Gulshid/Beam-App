import Foundation

protocol UserRepository {
    /// Loads a user's Firestore profile, creating one on first sign-in if it doesn't exist yet.
    func fetchOrCreateUser(uid: String, displayName: String, email: String?) async throws -> AppUser

    func fetchUser(uid: String) async throws -> AppUser?

    /// Explicitly writes a corrected display name to Firestore.
    /// Needed because the auth-state listener can create the user doc
    /// before FirebaseAuth's own profile update finishes committing.
    func updateDisplayName(uid: String, displayName: String) async throws

    /// For "add to chat" / "new conversation" search.
    func searchUsers(matching query: String) async throws -> [AppUser]

    func updateFCMToken(uid: String, token: String) async throws
}
