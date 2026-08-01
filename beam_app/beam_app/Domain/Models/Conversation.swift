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

    /// For direct chats, returns the other participant's uid.
    func otherMemberId(currentUserId: String) -> String? {
        guard type == .direct else { return nil }
        return memberIds.first { $0 != currentUserId }
    }
}
