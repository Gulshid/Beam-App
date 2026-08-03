import Foundation

@MainActor
final class StatusViewModel: ObservableObject {
    @Published private(set) var myStatuses: [Status] = []
    @Published private(set) var contactGroups: [StatusGroup] = []
    @Published private(set) var participantNames: [String: String] = [:]
    @Published var isPosting = false
    @Published var postErrorMessage: String?

    private let statusRepository: StatusRepository
    private let chatRepository: ChatRepository
    private let userRepository: UserRepository
    private let mediaRepository: MediaRepository

    private var contactsObserveTask: Task<Void, Never>?
    private var statusesObserveTask: Task<Void, Never>?
    // `nil` means "haven't received a conversations snapshot yet". Using an
    // optional (rather than defaulting straight to `[]`) is what lets the very
    // first snapshot always kick off `restartStatusesObserver()` below — even
    // when a brand-new user has zero conversations and the computed ids are
    // themselves an empty set. Without this, `[] != []` would be false and the
    // statuses listener (which is also how your *own* status gets watched)
    // would never start.
    private var contactIds: Set<String>? = nil
    private var currentUserId: String = ""

    init(
        statusRepository: StatusRepository = FirestoreStatusRepository(),
        chatRepository: ChatRepository = FirestoreChatRepository(),
        userRepository: UserRepository = FirestoreUserRepository(),
        mediaRepository: MediaRepository = CloudinaryMediaRepository()
    ) {
        self.statusRepository = statusRepository
        self.chatRepository = chatRepository
        self.userRepository = userRepository
        self.mediaRepository = mediaRepository
    }

    func start(currentUserId: String) {
        self.currentUserId = currentUserId

        // This app has no separate address-book/contacts sync, so "contacts" for the
        // Status tab means "everyone you already have a conversation with" —
        // Groups piggybacks on `Conversation` the same way elsewhere in the app.
        contactsObserveTask?.cancel()
        contactsObserveTask = Task {
            for await conversations in self.chatRepository.observeConversations(forUserId: currentUserId) {
                let ids = Set(conversations.flatMap(\.memberIds)).subtracting([currentUserId])
                guard ids != self.contactIds else { continue }
                self.contactIds = ids
                await self.loadParticipantNames(for: ids)
                self.restartStatusesObserver()
            }
        }
    }

    func stop() {
        contactsObserveTask?.cancel()
        statusesObserveTask?.cancel()
    }

    private func restartStatusesObserver() {
        statusesObserveTask?.cancel()
        let watchedIds = Array(contactIds ?? []) + [currentUserId]
        statusesObserveTask = Task {
            for await statuses in self.statusRepository.observeStatuses(for: watchedIds) {
                self.apply(statuses)
            }
        }
    }

    private func apply(_ statuses: [Status]) {
        myStatuses = statuses.filter { $0.userId == currentUserId }

        let othersByUser = Dictionary(grouping: statuses.filter { $0.userId != currentUserId }, by: \.userId)
        contactGroups = othersByUser
            .map { StatusGroup(userId: $0.key, statuses: $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { lhs, rhs in
                // Unread reels first (mirrors WhatsApp), newest-activity first within
                // each of those two buckets.
                let lhsUnviewed = lhs.hasUnviewed(for: currentUserId)
                let rhsUnviewed = rhs.hasUnviewed(for: currentUserId)
                if lhsUnviewed != rhsUnviewed { return lhsUnviewed }
                return (lhs.latest?.createdAt ?? .distantPast) > (rhs.latest?.createdAt ?? .distantPast)
            }
    }

    private func loadParticipantNames(for ids: Set<String>) async {
        let missing = ids.subtracting(participantNames.keys)
        guard !missing.isEmpty else { return }
        for uid in missing {
            if let user = try? await userRepository.fetchUser(uid: uid) {
                participantNames[uid] = user.displayName
            }
        }
    }

    func displayName(for userId: String) -> String {
        participantNames[userId] ?? "..."
    }

    // MARK: - Posting

    func postText(_ text: String, backgroundColorHex: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !currentUserId.isEmpty else { return false }

        isPosting = true
        defer { isPosting = false }
        do {
            try await statusRepository.postTextStatus(userId: currentUserId, text: trimmed, backgroundColorHex: backgroundColorHex)
            return true
        } catch {
            print("postText error: \(error)")
            postErrorMessage = "Couldn't post your status. Try again."
            return false
        }
    }

    func postImage(data: Data, caption: String?) async -> Bool {
        guard !currentUserId.isEmpty else { return false }

        isPosting = true
        defer { isPosting = false }
        do {
            let result = try await mediaRepository.upload(data: data, kind: .image) { _ in }
            let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
            try await statusRepository.postImageStatus(
                userId: currentUserId,
                mediaURL: result.url,
                caption: (trimmedCaption?.isEmpty ?? true) ? nil : trimmedCaption
            )
            return true
        } catch {
            print("postImage error: \(error)")
            postErrorMessage = "Couldn't post your status. Try again."
            return false
        }
    }

    // MARK: - Viewing

    /// No-op for your own status, or one you've already viewed — keeps this safe to
    /// call every time the viewer advances to a status without extra bookkeeping.
    func markViewed(_ status: Status) {
        guard status.userId != currentUserId, !status.isViewed(by: currentUserId) else { return }
        Task {
            try? await statusRepository.markViewed(statusId: status.id, viewerId: currentUserId)
        }
    }

    /// No-op on your own status — reactions are something viewers give you, not
    /// something you give yourself.
    func react(to status: Status, emoji: String) {
        guard status.userId != currentUserId else { return }
        Task {
            try? await statusRepository.reactToStatus(statusId: status.id, viewerId: currentUserId, emoji: emoji)
        }
    }

    /// The current user's own reaction to `status`, if any — lets the reaction
    /// bar highlight whichever emoji they already picked.
    func myReaction(to status: Status) -> String? {
        status.reaction(by: currentUserId)
    }

    /// One row per person who reacted, in the shape the reactions sheet displays:
    /// (display name, emoji). Used only for the poster viewing their own status.
    func reactionRows(for status: Status) -> [(name: String, emoji: String)] {
        (status.reactions ?? [:])
            .map { (name: participantNames[$0.key] ?? "Someone", emoji: $0.value) }
            .sorted { $0.name < $1.name }
    }

    func deleteMyStatus(_ status: Status) async {
        guard status.userId == currentUserId else { return }
        do {
            try await statusRepository.deleteStatus(statusId: status.id)
        } catch {
            print("deleteStatus error: \(error)")
        }
    }

    func viewerNames(for status: Status) -> [String] {
        (status.viewedBy ?? []).map { participantNames[$0] ?? "Someone" }
    }
}
