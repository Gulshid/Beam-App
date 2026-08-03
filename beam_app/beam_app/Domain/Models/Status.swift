import Foundation

enum StatusType: String, Codable {
    case text
    case image
}

/// A single status update ("story") — text or photo, visible to the poster's
/// contacts for 24h. Expiry is enforced client-side (`isExpired`) rather than by
/// deleting the Firestore doc on a timer, same free-tier tradeoff the rest of this
/// build makes elsewhere (no Cloud Functions): an expired doc just lingers,
/// filtered out of every read, until something eventually cleans it up.
struct Status: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    var type: StatusType
    /// Status text for `.text`; an optional caption for `.image`.
    var text: String?
    var mediaURL: String?
    /// Hex string, e.g. "#0A84FF" — only set for `.text`, one of a fixed palette
    /// the composer cycles through (mirrors WhatsApp's colored text-status cards).
    var backgroundColorHex: String?
    let createdAt: Date
    /// uids that have viewed this status. Optional (rather than defaulting to `[]`)
    /// so older/edge-case docs still decode cleanly — same pattern as
    /// `Conversation.unreadCounts`.
    var viewedBy: [String]? = nil
    /// uid -> single emoji. One reaction per viewer (re-tapping overwrites their
    /// previous emoji rather than stacking), stored as a flat map so it can be
    /// updated with a single dotted-field write (`reactions.<uid>`) without
    /// touching anyone else's reaction. Optional for the same reason `viewedBy` is.
    var reactions: [String: String]? = nil

    static let lifetime: TimeInterval = 24 * 60 * 60
    /// Fixed quick-reaction palette shown under someone else's status — mirrors the
    /// small fixed set WhatsApp/Instagram offer rather than a full emoji keyboard.
    static let quickReactions = ["❤️", "😂", "😮", "😢", "👏", "🔥"]

    var expiresAt: Date { createdAt.addingTimeInterval(Status.lifetime) }
    var isExpired: Bool { Date() >= expiresAt }

    func isViewed(by userId: String) -> Bool {
        viewedBy?.contains(userId) ?? false
    }

    func reaction(by userId: String) -> String? {
        reactions?[userId]
    }

    static func textDraft(userId: String, text: String, backgroundColorHex: String) -> Status {
        Status(
            id: UUID().uuidString,
            userId: userId,
            type: .text,
            text: text,
            mediaURL: nil,
            backgroundColorHex: backgroundColorHex,
            createdAt: Date(),
            viewedBy: []
        )
    }

    static func imageDraft(userId: String, mediaURL: String, caption: String?) -> Status {
        Status(
            id: UUID().uuidString,
            userId: userId,
            type: .image,
            text: caption,
            mediaURL: mediaURL,
            backgroundColorHex: nil,
            createdAt: Date(),
            viewedBy: []
        )
    }
}

/// One person's status "reel" — all of their non-expired statuses, oldest -> newest.
/// This is what both the Status tab's row and the full-screen viewer key off of.
struct StatusGroup: Identifiable, Equatable {
    let userId: String
    var statuses: [Status]

    var id: String { userId }
    var latest: Status? { statuses.last }

    func hasUnviewed(for currentUserId: String) -> Bool {
        statuses.contains { !$0.isViewed(by: currentUserId) }
    }
}
