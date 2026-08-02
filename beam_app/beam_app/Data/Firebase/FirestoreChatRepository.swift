import Foundation
import FirebaseFirestore

final class FirestoreChatRepository: ChatRepository {
    private let db = Firestore.firestore()
    private var conversationsCollection: CollectionReference { db.collection("conversations") }

    /// Typing docs are short-lived presence pings, not chat history, so they live in
    /// their own subcollection rather than on the conversation doc itself — that keeps
    /// every keystroke from rewriting (and re-triggering listeners on) the conversation
    /// metadata that drives the conversation list.
    private func typingCollection(_ conversationId: String) -> CollectionReference {
        conversationsCollection.document(conversationId).collection("typing")
    }

    /// A typing doc older than this is stale — the writer likely backgrounded the app,
    /// lost network, or crashed before clearing it — so readers ignore it rather than
    /// showing "typing..." forever.
    private static let typingStaleness: TimeInterval = 8

    // MARK: - Observing

    func observeConversations(forUserId userId: String) -> AsyncStream<[Conversation]> {
        AsyncStream { continuation in
            // NOTE: intentionally no `.order(by:)` here. Combining `arrayContains`
            // with `order(by:)` on a different field requires a Firestore composite
            // index; until that index finishes building, the listener fails with
            // "FAILED_PRECONDITION: query requires an index" and never delivers
            // updates again (which is why it can look like it "only works after
            // reloading the app" — a previous cold start happened to catch it after
            // the index was ready). Sorting client-side sidesteps the requirement.
            let listener = conversationsCollection
                .whereField("memberIds", arrayContains: userId)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("observeConversations error: \(error)")
                        return
                    }
                    guard let snapshot else { return }
                    let conversations = snapshot.documents
                        .compactMap { try? $0.data(as: Conversation.self) }
                        .filter { !($0.deletedFor?.contains(userId) ?? false) }
                        .sorted { $0.updatedAt > $1.updatedAt }
                    continuation.yield(conversations)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func observeConversation(conversationId: String) -> AsyncStream<Conversation?> {
        AsyncStream { continuation in
            let listener = conversationsCollection
                .document(conversationId)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("observeConversation error: \(error)")
                        return
                    }
                    guard let snapshot, snapshot.exists else {
                        continuation.yield(nil)
                        return
                    }
                    continuation.yield(try? snapshot.data(as: Conversation.self))
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func observeMessages(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            let listener = conversationsCollection
                .document(conversationId)
                .collection("messages")
                .order(by: "createdAt", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("observeMessages error: \(error)")
                        return
                    }
                    guard let snapshot else { return }
                    let messages = snapshot.documents.compactMap {
                        try? $0.data(as: Message.self)
                    }
                    continuation.yield(messages)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    // MARK: - Writing

    func startDirectConversation(currentUserId: String, otherUserId: String) async throws -> String {
        // Look for an existing direct conversation between exactly these two users.
        let snapshot = try await conversationsCollection
            .whereField("type", isEqualTo: ConversationType.direct.rawValue)
            .whereField("memberIds", arrayContains: currentUserId)
            .getDocuments()

        if let existing = snapshot.documents.first(where: { doc in
            guard let members = doc.data()["memberIds"] as? [String] else { return false }
            return Set(members) == Set([currentUserId, otherUserId])
        }) {
            return existing.documentID
        }

        let newConversation = Conversation(
            id: UUID().uuidString,
            type: .direct,
            memberIds: [currentUserId, otherUserId],
            title: nil,
            lastMessagePreview: nil,
            updatedAt: Date()
        )
        try conversationsCollection.document(newConversation.id).setData(from: newConversation)
        return newConversation.id
    }

    func createGroupConversation(title: String, memberIds: [String]) async throws -> String {
        let newConversation = Conversation(
            id: UUID().uuidString,
            type: .group,
            memberIds: memberIds,
            title: title,
            lastMessagePreview: nil,
            updatedAt: Date()
        )
        try conversationsCollection.document(newConversation.id).setData(from: newConversation)
        return newConversation.id
    }

    func renameGroup(conversationId: String, title: String) async throws {
        try await conversationsCollection.document(conversationId).setData([
            "title": title,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    func addMembers(conversationId: String, memberIds: [String]) async throws {
        try await conversationsCollection.document(conversationId).updateData([
            "memberIds": FieldValue.arrayUnion(memberIds)
        ])
    }

    /// Also used for "leave group": the leaving user calls this with their own uid.
    func removeMember(conversationId: String, userId: String) async throws {
        try await conversationsCollection.document(conversationId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])
    }

    func deleteConversation(conversationId: String, userId: String) async throws {
        try await conversationsCollection.document(conversationId).updateData([
            "deletedFor": FieldValue.arrayUnion([userId])
        ])
    }

    func sendMessage(_ message: Message, memberIds: [String]) async throws {
        let messageRef = conversationsCollection
            .document(message.conversationId)
            .collection("messages")
            .document(message.id)

        var sentMessage = message
        sentMessage.status = .sent
        try messageRef.setData(from: sentMessage)

        let conversationRef = conversationsCollection.document(message.conversationId)

        // Fallback for the (rare) case a message is sent before the conversation
        // snapshot has arrived on this device yet, so `memberIds` came in empty —
        // fetch it directly rather than silently skipping the unread fan-out.
        var resolvedMemberIds = memberIds
        if resolvedMemberIds.isEmpty {
            let snapshot = try? await conversationRef.getDocument()
            resolvedMemberIds = (try? snapshot?.data(as: Conversation.self))?.memberIds ?? []
        }

        var updates: [String: Any] = [
            "lastMessagePreview": previewText(for: sentMessage),
            "updatedAt": Timestamp(date: Date()),
            // A new message revives the conversation for anyone who'd previously
            // deleted it (WhatsApp-style) — including the sender, in case they're
            // the one restarting a thread they'd cleared from their own list.
            "deletedFor": []
        ]
        // Bump the unread badge for everyone but the sender. Client-side counter
        // rather than a Cloud Function trigger, same free-tier tradeoff as the rest
        // of this build (see blueprint §2/§7) — each recipient's own device zeroes
        // their count back out via `markConversationRead` when they open the chat.
        for uid in resolvedMemberIds where uid != message.senderId {
            updates["unreadCounts.\(uid)"] = FieldValue.increment(Int64(1))
        }

        // `updateData` (not `setData(merge:)`) is what actually guarantees the dot in
        // "unreadCounts.<uid>" is parsed as a nested-field path. `setData(merge:)` can
        // instead write it as one literal field literally named "unreadCounts.<uid>"
        // at the document's top level — which is why the badge wasn't showing up
        // even though lastMessagePreview/updatedAt (no dots) were updating fine.
        try await conversationRef.updateData(updates)
    }

    func markConversationRead(conversationId: String, userId: String) async throws {
        try await conversationsCollection.document(conversationId).updateData([
            "lastReadBy.\(userId)": Timestamp(date: Date()),
            "unreadCounts.\(userId)": 0
        ])
    }

    func updateMessageStatuses(conversationId: String, messageIds: [String], status: MessageStatus) async throws {
        guard !messageIds.isEmpty else { return }
        let messagesCollection = conversationsCollection.document(conversationId).collection("messages")
        let batch = db.batch()
        for id in messageIds {
            batch.updateData(["status": status.rawValue], forDocument: messagesCollection.document(id))
        }
        try await batch.commit()
    }

    // MARK: - Typing

    func setTyping(conversationId: String, userId: String, isTyping: Bool) async throws {
        try await typingCollection(conversationId).document(userId).setData([
            "isTyping": isTyping,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    func observeTypingUsers(conversationId: String, excluding currentUserId: String) -> AsyncStream<[String]> {
        AsyncStream { continuation in
            let listener = typingCollection(conversationId)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        print("observeTypingUsers error: \(error)")
                        return
                    }
                    guard let snapshot else { return }
                    let now = Date()
                    let typingIds = snapshot.documents.compactMap { doc -> String? in
                        guard doc.documentID != currentUserId else { return nil }
                        let data = doc.data()
                        guard let isTyping = data["isTyping"] as? Bool, isTyping else { return nil }
                        guard let timestamp = data["updatedAt"] as? Timestamp,
                              now.timeIntervalSince(timestamp.dateValue()) < FirestoreChatRepository.typingStaleness
                        else { return nil }
                        return doc.documentID
                    }
                    continuation.yield(typingIds)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    private func previewText(for message: Message) -> String {
        switch message.type {
        case .text: return message.text ?? ""
        case .image: return "📷 Photo"
        case .video: return "🎥 Video"
        case .audio: return "🎤 Voice message"
        }
    }
}
