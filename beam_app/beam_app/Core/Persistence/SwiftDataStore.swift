import Foundation
import SwiftData

/// Local, offline-first cache for conversations and messages.
///
/// ViewModels depend on this instead of talking to `ModelContext` directly — the same
/// "depend on an abstraction" rule the blueprint applies to `ChatRepository` /
/// `MediaRepository`. `@ModelActor` runs all of this off the main actor, which is what
/// lets `ChatViewModel` (main-actor) safely `await` into it from Firestore listener
/// callbacks without blocking the UI.
@ModelActor
actor SwiftDataStore {
    static let shared: SwiftDataStore = {
        let schema = Schema([CachedConversation.self, CachedMessage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            fatalError("SwiftDataStore: failed to create local ModelContainer")
        }
        return SwiftDataStore(modelContainer: container)
    }()

    // MARK: - Conversations

    /// Upserts a full server snapshot (what `observeConversations` yields each time).
    func upsertConversations(_ conversations: [Conversation]) {
        for conversation in conversations {
            let id = conversation.id
            let descriptor = FetchDescriptor<CachedConversation>(predicate: #Predicate { $0.id == id })
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.update(from: conversation)
            } else {
                modelContext.insert(CachedConversation(conversation))
            }
        }
        try? modelContext.save()
    }

    /// Instant cold-launch data — read before any Firestore listener has reconnected.
    func fetchCachedConversations() -> [Conversation] {
        let descriptor = FetchDescriptor<CachedConversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).map { $0.toDomain() }
    }

    /// Called right after a user deletes a chat, so the row doesn't briefly
    /// reappear from cache on the next cold launch before the server confirms it's
    /// filtered out of `observeConversations`.
    func deleteCachedConversation(id: String) {
        let descriptor = FetchDescriptor<CachedConversation>(predicate: #Predicate { $0.id == id })
        guard let existing = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(existing)
        try? modelContext.save()
    }

    // MARK: - Messages

    func upsertMessages(_ messages: [Message], conversationId: String) {
        for message in messages {
            let id = message.id
            let descriptor = FetchDescriptor<CachedMessage>(predicate: #Predicate { $0.id == id })
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.update(from: message)
            } else {
                modelContext.insert(CachedMessage(message))
            }
        }
        try? modelContext.save()
    }

    func fetchCachedMessages(conversationId: String) -> [Message] {
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).map { $0.toDomain() }
    }

    /// Messages still stuck at `.sending` for this conversation — either the app was
    /// killed mid-send, or the device was offline when send was tapped. Read on
    /// reconnect to resume the outgoing queue.
    func fetchPendingMessages(conversationId: String) -> [Message] {
        let sendingRaw = MessageStatus.sending.rawValue
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.conversationId == conversationId && $0.statusRaw == sendingRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).map { $0.toDomain() }
    }

    func updateMessageStatus(id: String, status: MessageStatus) {
        let descriptor = FetchDescriptor<CachedMessage>(predicate: #Predicate { $0.id == id })
        guard let existing = try? modelContext.fetch(descriptor).first else { return }
        existing.statusRaw = status.rawValue
        try? modelContext.save()
    }
}
