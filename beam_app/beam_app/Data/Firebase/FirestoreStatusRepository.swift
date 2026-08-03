import Foundation
import FirebaseFirestore

final class FirestoreStatusRepository: StatusRepository {
    private let db = Firestore.firestore()
    private var statusesCollection: CollectionReference { db.collection("statuses") }

    func observeStatuses(for userIds: [String]) -> AsyncStream<[Status]> {
        AsyncStream { continuation in
            guard !userIds.isEmpty else {
                continuation.yield([])
                continuation.finish()
                return
            }

            // Firestore's `in` operator caps at 30 values. Fine at the contact-list
            // scale this app targets elsewhere (see the free-tier framing on
            // `FirestoreChatRepository.observeTypingUsers`); a larger app would
            // shard this into multiple listeners merged client-side.
            let watchedIds = Array(userIds.prefix(30))

            let listener = statusesCollection
                .whereField("userId", in: watchedIds)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("observeStatuses error: \(error)")
                        return
                    }
                    guard let snapshot else { return }
                    let statuses = snapshot.documents
                        .compactMap { try? $0.data(as: Status.self) }
                        .filter { !$0.isExpired }
                        .sorted { $0.createdAt < $1.createdAt }
                    continuation.yield(statuses)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func postTextStatus(userId: String, text: String, backgroundColorHex: String) async throws {
        let status = Status.textDraft(userId: userId, text: text, backgroundColorHex: backgroundColorHex)
        try statusesCollection.document(status.id).setData(from: status)
    }

    func postImageStatus(userId: String, mediaURL: String, caption: String?) async throws {
        let status = Status.imageDraft(userId: userId, mediaURL: mediaURL, caption: caption)
        try statusesCollection.document(status.id).setData(from: status)
    }

    func markViewed(statusId: String, viewerId: String) async throws {
        try await statusesCollection.document(statusId).updateData([
            "viewedBy": FieldValue.arrayUnion([viewerId])
        ])
    }

    func reactToStatus(statusId: String, viewerId: String, emoji: String) async throws {
        // Dotted field path so this only ever touches this one viewer's entry in
        // the map — never overwrites anyone else's reaction, and the security
        // rule sees the top-level affected key as just "reactions".
        try await statusesCollection.document(statusId).updateData([
            "reactions.\(viewerId)": emoji
        ])
    }

    func deleteStatus(statusId: String) async throws {
        try await statusesCollection.document(statusId).delete()
    }
}
