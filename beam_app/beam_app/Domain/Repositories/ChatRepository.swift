import Foundation

protocol ChatRepository {
    /// Live stream of the current user's conversations, ordered by most recent activity.
    func observeConversations(forUserId userId: String) -> AsyncStream<[Conversation]>

    /// Live stream of a single conversation's own metadata (title, memberIds, etc) — used
    /// by the chat header/title and the group info screen, distinct from the messages inside it.
    func observeConversation(conversationId: String) -> AsyncStream<Conversation?>

    /// Live stream of messages within a single conversation, ordered oldest -> newest.
    func observeMessages(conversationId: String) -> AsyncStream<[Message]>

    /// Creates a direct (1:1) conversation if one doesn't already exist between the two users,
    /// and returns its id either way.
    func startDirectConversation(currentUserId: String, otherUserId: String) async throws -> String

    func createGroupConversation(title: String, memberIds: [String]) async throws -> String

    func renameGroup(conversationId: String, title: String) async throws

    func addMembers(conversationId: String, memberIds: [String]) async throws

    /// Also used for "leave group" — the leaving user removes themselves.
    func removeMember(conversationId: String, userId: String) async throws

    func sendMessage(_ message: Message) async throws

    func markConversationRead(conversationId: String, userId: String) async throws

    /// Batch-updates the given messages' status (e.g. sent -> delivered -> read).
    func updateMessageStatuses(conversationId: String, messageIds: [String], status: MessageStatus) async throws
}
