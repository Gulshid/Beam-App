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

    /// For direct chats, returns the other participant's uid.
    func otherMemberId(currentUserId: String) -> String? {
        guard type == .direct else { return nil }
        return memberIds.first { $0 != currentUserId }
    }

    func unreadCount(for userId: String) -> Int {
        unreadCounts?[userId] ?? 0
    }
}
