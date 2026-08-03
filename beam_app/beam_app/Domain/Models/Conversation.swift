import Foundation

enum ConversationType: String, Codable {
    case direct
    case group
}

struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    var type: ConversationType
    var memberIds: [String]
    var title: String?              // used for groups; direct chats derive display name from the other member
    var lastMessagePreview: String?
    var updatedAt: Date
    /// uid -> number of unread messages for that member. Optional (rather than
    /// defaulting to `[:]`) so conversations written before this field existed still
    /// decode cleanly instead of failing `.data(as:)` entirely.
    var unreadCounts: [String: Int]? = nil
    /// uid -> the moment that user "deleted" this conversation (WhatsApp-style: it
    /// just hides things for that user, nothing is actually removed server-side).
    /// Two things key off this cutoff:
    ///  - the conversation is hidden from that user's chat list as long as
    ///    `updatedAt <= clearedAt[uid]` (see `FirestoreChatRepository.observeConversations`)
    ///    — a later message naturally pushes `updatedAt` past the cutoff, which is
    ///    what makes the thread reappear on its own, no extra "undelete" write needed.
    ///  - that user's message list hides anything sent at or before the cutoff (see
    ///    `ChatViewModel`), so re-messaging the same person starts a clean thread
    ///    instead of resurrecting the old history.
    var clearedAt: [String: Date]? = nil

    /// For direct chats, returns the other participant's uid.
    func otherMemberId(currentUserId: String) -> String? {
        guard type == .direct else { return nil }
        return memberIds.first { $0 != currentUserId }
    }

    func unreadCount(for userId: String) -> Int {
        unreadCounts?[userId] ?? 0
    }
}
