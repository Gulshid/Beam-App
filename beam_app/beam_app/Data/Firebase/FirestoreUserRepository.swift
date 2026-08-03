import Foundation
import FirebaseFirestore

final class FirestoreUserRepository: UserRepository {
    private let db = Firestore.firestore()
    private var usersCollection: CollectionReference { db.collection("users") }

    func fetchOrCreateUser(uid: String, displayName: String, email: String?) async throws -> AppUser {
        let docRef = usersCollection.document(uid)
        let snapshot = try await docRef.getDocument()

        if snapshot.exists, let existing = try? snapshot.data(as: AppUser.self) {
            return existing
        }

        let newUser = AppUser(id: uid, displayName: displayName, email: email)
        try docRef.setData(from: newUser, merge: true)
        // Denormalized lowercase field to support the prefix search in searchUsers(matching:).
        try await docRef.setData(["displayNameLowercase": displayName.lowercased()], merge: true)
        return newUser
    }

    func fetchUser(uid: String) async throws -> AppUser? {
        let snapshot = try await usersCollection.document(uid).getDocument()
        return try? snapshot.data(as: AppUser.self)
    }

    func searchUsers(matching query: String, excluding currentUserId: String?) async throws -> [AppUser] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        // Simple prefix search on displayName. Firestore has no native full-text search;
        // for a production app consider Algolia/Typesense synced via Cloud Functions.
        let lowerBound = query.lowercased()
        let upperBound = lowerBound + "\u{f8ff}"

        // Fetch one extra so filtering out the current user doesn't leave us
        // short of results when they happen to match the prefix.
        let snapshot = try await usersCollection
            .whereField("displayNameLowercase", isGreaterThanOrEqualTo: lowerBound)
            .whereField("displayNameLowercase", isLessThanOrEqualTo: upperBound)
            .limit(to: 21)
            .getDocuments()

        let users = snapshot.documents.compactMap { try? $0.data(as: AppUser.self) }
        guard let currentUserId else { return users }
        return users.filter { $0.id != currentUserId }
    }

    func updateDisplayName(uid: String, displayName: String) async throws {
        try await usersCollection.document(uid).setData([
            "displayName": displayName,
            "displayNameLowercase": displayName.lowercased()
        ], merge: true)
    }

    func updateFCMToken(uid: String, token: String) async throws {
        try await usersCollection.document(uid).setData(["fcmToken": token], merge: true)
    }

    func updatePhotoURL(uid: String, photoURL: String) async throws {
        try await usersCollection.document(uid).setData(["photoURL": photoURL], merge: true)
    }

    func deleteUserProfile(uid: String) async throws {
        try await usersCollection.document(uid).delete()
    }
}
