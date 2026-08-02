import Foundation

protocol ChatRepository {
    /// Live stream of the current user's conversations, ordered by most recent activity.
    func observeConversations(forUserId userId: String) -> AsyncStream<[Conversation]>

    /// Live stream of messages within a single conversation, ordered oldest -> newest.
    func observeMessages(conversationId: String) -> AsyncStream<[Message]>

    /// Creates a direct (1:1) conversation if one doesn't already exist between the two users,
    /// and returns its id either way.
    func startDirectConversation(currentUserId: String, otherUserId: String) async throws -> String

    func createGroupConversation(title: String, memberIds: [String]) async throws -> String

    func sendMessage(_ message: Message) async throws

    func markConversationRead(conversationId: String, userId: String) async throws

    /// Batch-updates the given messages' status (e.g. sent -> delivered -> read).
    func updateMessageStatuses(conversationId: String, messageIds: [String], status: MessageStatus) async throws
}
