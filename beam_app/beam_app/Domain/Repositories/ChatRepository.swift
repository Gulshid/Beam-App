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

    /// Hides the conversation, and everything sent in it up to now, from `userId`'s
    /// own view (WhatsApp-style: nothing is actually deleted server-side — see
    /// `Conversation.clearedAt`). It drops out of `observeConversations` for this
    /// user immediately, and re-messaging the same person/group later starts a
    /// clean thread rather than resurfacing the old history.
    func deleteConversation(conversationId: String, userId: String) async throws

    /// `memberIds` is the conversation's current member list, used to increment
    /// `unreadCounts` for everyone except the sender. Passed in rather than looked up
    /// server-side so a normal send doesn't cost an extra read — callers already have
    /// it from the conversation they're sending into (`ChatViewModel.conversation`).
    func sendMessage(_ message: Message, memberIds: [String]) async throws

    func markConversationRead(conversationId: String, userId: String) async throws

    /// Batch-updates the given messages' status (e.g. sent -> delivered -> read).
    func updateMessageStatuses(conversationId: String, messageIds: [String], status: MessageStatus) async throws

    /// "Delete for me": hides this one message from `userId` only. Nothing else
    /// about the message, or anyone else's view of it, changes.
    func deleteMessageForMe(conversationId: String, messageId: String, userId: String) async throws

    /// "Delete for everyone": wipes the message's content server-side (so it's
    /// gone from every client, not just hidden) and flips `deletedForEveryone`.
    /// Only the original sender is allowed to do this — enforced in security rules.
    func deleteMessageForEveryone(conversationId: String, messageId: String) async throws

    /// Sets (or overwrites) `viewerId`'s single emoji reaction on this message.
    func reactToMessage(conversationId: String, messageId: String, viewerId: String, emoji: String) async throws

    /// Writes this user's live typing state for the conversation. Called on every
    /// keystroke (true) and on send/idle-timeout/leave (false) — see
    /// `ChatViewModel.userIsTyping`.
    func setTyping(conversationId: String, userId: String, isTyping: Bool) async throws

    /// Live stream of uids currently typing in this conversation, excluding the
    /// caller. Entries older than a few seconds are treated as stale (covers a
    /// client that crashed or lost network before it could write `isTyping: false`).
    func observeTypingUsers(conversationId: String, excluding currentUserId: String) -> AsyncStream<[String]>
}
