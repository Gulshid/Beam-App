import Foundation
import SwiftData

/// SwiftData mirror of `Conversation`. Kept as a separate type (rather than making the
/// Domain struct itself a `@Model`) so Domain stays framework-free — Data/Persistence is
/// the only layer that knows SwiftData exists, same rule the blueprint applies to Firebase.
@Model
final class CachedConversation {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var memberIds: [String]
    var title: String?
    var lastMessagePreview: String?
    var updatedAt: Date
    /// JSON-encoded `[String: Int]` (uid -> unread count) — same "raw storage,
    /// decode on read" approach as `statusRaw` below, so this stays a plain,
    /// predictable SwiftData column rather than depending on Dictionary support.
    var unreadCountsData: Data?
    /// JSON-encoded `[String: Date]` mirror of `Conversation.clearedAt` — cached too
    /// so `ChatViewModel`'s cold-launch cache read (before the listener reconnects)
    /// still knows to hide pre-delete messages instead of flashing them briefly.
    var clearedAtData: Data?

    init(_ conversation: Conversation) {
        id = conversation.id
        typeRaw = conversation.type.rawValue
        memberIds = conversation.memberIds
        title = conversation.title
        lastMessagePreview = conversation.lastMessagePreview
        updatedAt = conversation.updatedAt
        unreadCountsData = try? JSONEncoder().encode(conversation.unreadCounts ?? [:])
        clearedAtData = try? JSONEncoder().encode(conversation.clearedAt ?? [:])
    }

    func update(from conversation: Conversation) {
        typeRaw = conversation.type.rawValue
        memberIds = conversation.memberIds
        title = conversation.title
        lastMessagePreview = conversation.lastMessagePreview
        updatedAt = conversation.updatedAt
        unreadCountsData = try? JSONEncoder().encode(conversation.unreadCounts ?? [:])
        clearedAtData = try? JSONEncoder().encode(conversation.clearedAt ?? [:])
    }

    func toDomain() -> Conversation {
        let unreadCounts = unreadCountsData.flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) }
        let clearedAt = clearedAtData.flatMap { try? JSONDecoder().decode([String: Date].self, from: $0) }
        return Conversation(
            id: id,
            type: ConversationType(rawValue: typeRaw) ?? .direct,
            memberIds: memberIds,
            title: title,
            lastMessagePreview: lastMessagePreview,
            updatedAt: updatedAt,
            unreadCounts: unreadCounts,
            clearedAt: clearedAt
        )
    }
}

/// SwiftData mirror of `Message`. Statuses are stored raw (String) rather than as the
/// `MessageStatus` enum directly since `@Model` properties need to be simple/Codable-free
/// value types for predicates to work reliably.
@Model
final class CachedMessage {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var typeRaw: String
    var text: String?
    var mediaURL: String?
    var duration: Double?
    var createdAt: Date
    var statusRaw: String

    init(_ message: Message) {
        id = message.id
        conversationId = message.conversationId
        senderId = message.senderId
        typeRaw = message.type.rawValue
        text = message.text
        mediaURL = message.mediaURL
        duration = message.duration
        createdAt = message.createdAt
        statusRaw = message.status.rawValue
    }

    func update(from message: Message) {
        typeRaw = message.type.rawValue
        text = message.text
        mediaURL = message.mediaURL
        duration = message.duration
        statusRaw = message.status.rawValue
        // id / conversationId / senderId / createdAt don't change once a message exists.
    }

    func toDomain() -> Message {
        Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            type: MessageType(rawValue: typeRaw) ?? .text,
            text: text,
            mediaURL: mediaURL,
            duration: duration,
            createdAt: createdAt,
            status: MessageStatus(rawValue: statusRaw) ?? .sent
        )
    }
}
