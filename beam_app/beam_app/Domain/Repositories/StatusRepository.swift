import Foundation

protocol StatusRepository {
    /// Live stream of every non-expired status posted by any of `userIds` (typically
    /// the current user's contacts, derived from their conversations, plus
    /// themselves — see `StatusViewModel`). Yields the full set on every change,
    /// same "no incremental diffing" shape as `ChatRepository.observeConversations`.
    func observeStatuses(for userIds: [String]) -> AsyncStream<[Status]>

    func postTextStatus(userId: String, text: String, backgroundColorHex: String) async throws

    func postImageStatus(userId: String, mediaURL: String, caption: String?) async throws

    func markViewed(statusId: String, viewerId: String) async throws

    /// Sets (or overwrites) `viewerId`'s single emoji reaction on this status.
    func reactToStatus(statusId: String, viewerId: String, emoji: String) async throws

    /// Lets the poster remove their own status before its 24h expiry.
    func deleteStatus(statusId: String) async throws
}
