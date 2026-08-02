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

    static func draft(conversationId: String, senderId: String, text: String) -> Message {
        Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            type: .text,
            text: text,
            mediaURL: nil,
            duration: nil,
            createdAt: Date(),
            status: .sending
        )
    }

    /// Local placeholder shown immediately while a photo/video/voice message uploads.
    /// `mediaURL` is filled in once the upload completes (see ChatViewModel.sendMedia).
    static func mediaDraft(conversationId: String, senderId: String, type: MessageType, duration: Double? = nil) -> Message {
        Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            type: type,
            text: nil,
            mediaURL: nil,
            duration: duration,
            createdAt: Date(),
            status: .sending
        )
    }
}
