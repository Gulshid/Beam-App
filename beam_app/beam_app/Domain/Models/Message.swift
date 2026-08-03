import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case video
    case audio
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

enum MessageReactionPalette {
    static let quickReactions = ["❤️", "😂", "😮", "😢", "🙏", "👍"]
}

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    var type: MessageType
    var text: String?               // plaintext for now; Phase 3 replaces this with ciphertext
    var mediaURL: String?           // populated in Phase 2
    var duration: Double?           // for audio/video, populated in Phase 2
    var createdAt: Date
    var status: MessageStatus

    /// Set when this message was sent as a reply. The quoted snippet is captured
    /// at send time (sender name + a short preview string) rather than resolved
    /// by looking the original message up live — that way the quote still renders
    /// correctly even if the original was later deleted-for-everyone, exactly like
    /// WhatsApp's own "this message was deleted" quoted-reply behavior.
    var replyToMessageId: String? = nil
    var replyPreviewSenderName: String? = nil
    var replyPreviewText: String? = nil

    /// uids who have deleted this message "for me". Purely local-to-them hiding —
    /// the message (and everyone else's copy of it) is untouched. Mirrors
    /// `Conversation.clearedAt`'s "hide, don't destroy" approach.
    var deletedFor: [String]? = nil
    /// True once the sender has deleted this message "for everyone". When set,
    /// `text`/`mediaURL`/`duration` are wiped server-side and every client renders
    /// the "This message was deleted" placeholder instead of the original content.
    var deletedForEveryone: Bool? = nil
    /// uid -> single emoji, one reaction per person (re-tapping overwrites their
    /// previous emoji rather than stacking) — same shape as `Status.reactions`.
    var reactions: [String: String]? = nil

    var isDeletedForEveryone: Bool { deletedForEveryone ?? false }

    func isDeletedForMe(_ userId: String) -> Bool {
        deletedFor?.contains(userId) ?? false
    }

    func reaction(by userId: String) -> String? {
        reactions?[userId]
    }

    static func draft(
        conversationId: String,
        senderId: String,
        text: String,
        replyTo: Message? = nil,
        replySenderName: String? = nil
    ) -> Message {
        Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            type: .text,
            text: text,
            mediaURL: nil,
            duration: nil,
            createdAt: Date(),
            status: .sending,
            replyToMessageId: replyTo?.id,
            replyPreviewSenderName: replyTo.map { _ in replySenderName ?? "You" },
            replyPreviewText: replyTo.map(Message.previewSnippet)
        )
    }

    /// Local placeholder shown immediately while a photo/video/voice message uploads.
    /// `mediaURL` is filled in once the upload completes (see ChatViewModel.sendMedia).
    static func mediaDraft(
        conversationId: String,
        senderId: String,
        type: MessageType,
        duration: Double? = nil,
        replyTo: Message? = nil,
        replySenderName: String? = nil
    ) -> Message {
        Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            type: type,
            text: nil,
            mediaURL: nil,
            duration: duration,
            createdAt: Date(),
            status: .sending,
            replyToMessageId: replyTo?.id,
            replyPreviewSenderName: replyTo.map { _ in replySenderName ?? "You" },
            replyPreviewText: replyTo.map(Message.previewSnippet)
        )
    }

    /// Short one-line summary of a message, used both for the quoted-reply preview
    /// captured at send time and (via the same idea) a conversation's last-message
    /// preview elsewhere in the app.
    static func previewSnippet(for message: Message) -> String {
        if message.isDeletedForEveryone { return "This message was deleted" }
        switch message.type {
        case .text: return message.text ?? ""
        case .image: return "📷 Photo"
        case .video: return "🎥 Video"
        case .audio: return "🎤 Voice message"
        }
    }
}
