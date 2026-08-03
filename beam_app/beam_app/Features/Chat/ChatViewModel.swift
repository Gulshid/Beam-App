import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published var draftText = ""
    @Published private(set) var isSending = false
    /// messageId -> 0...1 upload fraction, for messages currently uploading media.
    @Published private(set) var uploadProgress: [String: Double] = [:]
    /// The conversation's own metadata (type, memberIds, title) — nil until the first
    /// snapshot arrives. Used for the nav title and to decide whether this is a group.
    @Published private(set) var conversation: Conversation?
    @Published private(set) var navigationTitle: String = ""
    /// Display names of whoever else is currently typing in this conversation
    /// (already excludes the current user — see `observeTypingUsers`).
    @Published private(set) var typingUserNames: [String] = []
    /// The message the composer is currently replying to, if any. Cleared
    /// automatically once the reply is sent (see sendDraft/sendMedia).
    @Published var replyingTo: Message?

    /// In-chat message search. `searchMatchIds` is the ordered list of message ids
    /// (oldest -> newest, matching `messages`) whose text matches `searchQuery`;
    /// `currentSearchMatchIndex` is which of those the user is currently viewing.
    @Published var searchQuery = "" {
        didSet { runSearch() }
    }
    @Published private(set) var searchMatchIds: [String] = []
    @Published private(set) var currentSearchMatchIndex = 0

    var currentSearchMatchId: String? {
        guard searchMatchIds.indices.contains(currentSearchMatchIndex) else { return nil }
        return searchMatchIds[currentSearchMatchIndex]
    }

    let conversationId: String
    private let chatRepository: ChatRepository
    private let mediaRepository: MediaRepository
    private let userRepository: UserRepository
    private let localStore: SwiftDataStore
    private var observeTask: Task<Void, Never>?
    private var conversationObserveTask: Task<Void, Never>?
    private var typingObserveTask: Task<Void, Never>?
    /// Debounce/idle-timeout for outgoing typing state — see `userIsTyping`.
    private var stopTypingTask: Task<Void, Never>?
    private var isCurrentlyTyping = false
    private var reachabilityCancellable: AnyCancellable?
    private var currentUserId: String = ""
    private var wasOffline = false
    /// uid -> displayName, populated for group members only (used for the sender label
    /// shown above incoming bubbles — direct chats don't need it).
    private var memberNames: [String: String] = [:]

    /// This user's "deleted the chat" cutoff, if any (see `Conversation.clearedAt`).
    /// Messages sent at or before this are hidden from `messages`/search even once
    /// the conversation itself reappears after a newer message.
    private var clearedAtCutoff: Date?

    init(
        conversationId: String,
        chatRepository: ChatRepository = FirestoreChatRepository(),
        mediaRepository: MediaRepository = CloudinaryMediaRepository(),
        userRepository: UserRepository = FirestoreUserRepository(),
        localStore: SwiftDataStore = .shared
    ) {
        self.conversationId = conversationId
        self.chatRepository = chatRepository
        self.mediaRepository = mediaRepository
        self.userRepository = userRepository
        self.localStore = localStore
    }

    /// Nil for direct chats. For group chats, the display name of whoever sent this
    /// message — shown above incoming bubbles, mirroring the usual group-chat pattern.
    func senderName(for message: Message) -> String? {
        guard conversation?.type == .group else { return nil }
        return memberNames[message.senderId]
    }

    /// Display name for a quoted-reply preview — "You" for the current user's own
    /// messages, otherwise the same lookup `senderName(for:)` uses.
    func replySenderLabel(for message: Message, currentUserId: String) -> String {
        message.senderId == currentUserId ? "You" : (memberNames[message.senderId] ?? "Someone")
    }

    func beginReply(to message: Message) {
        replyingTo = message
    }

    func cancelReply() {
        replyingTo = nil
    }

    /// "Delete for me": hides it from this device/account only. Works on any
    /// message, yours or theirs.
    func deleteForMe(_ message: Message, currentUserId: String) async {
        messages.removeAll { $0.id == message.id }
        do {
            try await chatRepository.deleteMessageForMe(conversationId: conversationId, messageId: message.id, userId: currentUserId)
        } catch {
            print("deleteMessageForMe error: \(error)")
        }
    }

    /// "Delete for everyone": only valid for your own messages — the context menu
    /// in the view already hides this option otherwise, but guard here too in case
    /// a stale menu is still on screen.
    func deleteForEveryone(_ message: Message, currentUserId: String) async {
        guard message.senderId == currentUserId else { return }
        do {
            try await chatRepository.deleteMessageForEveryone(conversationId: conversationId, messageId: message.id)
        } catch {
            print("deleteMessageForEveryone error: \(error)")
        }
    }

    /// No-op reacting to your own message — same rule `StatusViewModel.react`
    /// applies to your own status.
    func react(to message: Message, emoji: String, currentUserId: String) {
        Task {
            try? await chatRepository.reactToMessage(
                conversationId: conversationId, messageId: message.id, viewerId: currentUserId, emoji: emoji
            )
        }
    }

    func myReaction(to message: Message, currentUserId: String) -> String? {
        message.reaction(by: currentUserId)
    }

    /// Scrolls to and briefly highlights the message a reply is quoting, if it's
    /// still around (it may have scrolled out of the loaded window, or been
    /// deleted-for-me on this device — either way there's nothing to jump to).
    func message(withId id: String) -> Message? {
        messages.first { $0.id == id }
    }

    /// - Parameter currentUserId: needed so we know which messages are "incoming" and can be
    ///   advanced from sent -> delivered -> read as this device receives/views them.
    func start(currentUserId: String) {
        self.currentUserId = currentUserId

        // Cold-launch / offline: paint whatever's cached instantly, before Firestore's
        // listener has had a chance to (re)connect.
        Task {
            if let cachedConversation = await self.localStore.fetchCachedConversation(id: self.conversationId) {
                self.clearedAtCutoff = cachedConversation.clearedAt?[currentUserId]
            }
            let cached = await self.localStore.fetchCachedMessages(conversationId: self.conversationId)
            if self.messages.isEmpty && !cached.isEmpty {
                self.messages = self.filterCleared(cached)
            }
        }

        observeTask?.cancel()
        observeTask = Task {
            for await updated in chatRepository.observeMessages(conversationId: conversationId) {
                let visible = self.filterCleared(updated)
                self.reconcile(with: visible)
                self.runSearch()
                await self.localStore.upsertMessages(visible, conversationId: conversationId)
                await self.advanceIncomingMessageStatuses(visible)
                // This screen is open and rendering the conversation, so it's read —
                // zero the unread badge back to 0 for this device's user. Same idea as
                // advanceIncomingMessageStatuses above, just at the conversation level
                // instead of per-message.
                if !currentUserId.isEmpty {
                    try? await self.chatRepository.markConversationRead(conversationId: self.conversationId, userId: currentUserId)
                }
            }
        }

        conversationObserveTask?.cancel()
        conversationObserveTask = Task {
            for await updated in chatRepository.observeConversation(conversationId: conversationId) {
                guard let updated else { continue }
                self.conversation = updated
                let newCutoff = updated.clearedAt?[currentUserId]
                if newCutoff != self.clearedAtCutoff {
                    // The cutoff just changed (e.g. this device deleted the chat from
                    // another session) — re-apply it to whatever's already on screen
                    // rather than waiting on the next message snapshot.
                    self.clearedAtCutoff = newCutoff
                    self.messages = self.filterCleared(self.messages)
                    self.runSearch()
                }
                await self.updateTitleAndMemberNames(updated, currentUserId: currentUserId)
            }
        }

        typingObserveTask?.cancel()
        typingObserveTask = Task {
            for await typingIds in chatRepository.observeTypingUsers(conversationId: conversationId, excluding: currentUserId) {
                // Names may not be resolved yet the very first time a peer starts typing
                // in a direct chat (memberNames backfills from updateTitleAndMemberNames);
                // fall back to a generic label rather than showing nothing.
                self.typingUserNames = typingIds.map { self.memberNames[$0] ?? "Someone" }
            }
        }

        // As soon as connectivity flips back on, resume anything left in "sending"
        // (covers both "was offline when send was tapped" and "app got killed mid-send").
        wasOffline = !Reachability.shared.isOnline
        reachabilityCancellable = Reachability.shared.$isOnline
            .removeDuplicates()
            .sink { [weak self] isOnline in
                guard let self else { return }
                if isOnline && self.wasOffline {
                    Task { await self.retryPendingMessages() }
                }
                self.wasOffline = !isOnline
            }
    }

    /// Re-sends anything still marked `.sending` in the local cache. `Message.id` is
    /// generated client-side and reused as the Firestore document id, so replaying the
    /// same message is an idempotent overwrite rather than a duplicate send.
    private func retryPendingMessages() async {
        let pending = await localStore.fetchPendingMessages(conversationId: conversationId)
        for message in pending {
            do {
                try await chatRepository.sendMessage(message, memberIds: conversation?.memberIds ?? [])
                await localStore.updateMessageStatus(id: message.id, status: .sent)
                if let index = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[index].status = .sent
                }
            } catch {
                // Still offline, or a real failure — either way it stays "sending" and
                // gets picked up again on the next reconnect.
                print("retryPendingMessages error: \(error)")
            }
        }
    }

    /// Resolves the nav title (group title, or the other participant's name for a
    /// direct chat) and, for groups, backfills `memberNames` for any member not yet
    /// looked up so incoming bubbles can show a sender label.
    private func updateTitleAndMemberNames(_ conversation: Conversation, currentUserId: String) async {
        switch conversation.type {
        case .group:
            navigationTitle = conversation.title ?? "Group Chat"
            let missingIds = Set(conversation.memberIds).subtracting(memberNames.keys)
            for uid in missingIds {
                if let user = try? await userRepository.fetchUser(uid: uid) {
                    memberNames[uid] = user.displayName
                }
            }
        case .direct:
            guard let otherId = conversation.otherMemberId(currentUserId: currentUserId) else {
                navigationTitle = "Conversation"
                return
            }
            if let cachedName = memberNames[otherId] {
                navigationTitle = cachedName
            } else if let user = try? await userRepository.fetchUser(uid: otherId) {
                memberNames[otherId] = user.displayName
                navigationTitle = user.displayName
            } else {
                navigationTitle = "Conversation"
            }
        }
    }

    /// Drops anything sent at or before this user's `clearedAt` cutoff (see
    /// `Conversation.clearedAt`), and anything this user has individually
    /// "deleted for me" (see `Message.deletedFor`) — applied before a message list
    /// reaches `messages`, the cache, or delivery/read-receipt processing, so
    /// neither ever resurfaces even after the thread itself reappears.
    private func filterCleared(_ messages: [Message]) -> [Message] {
        messages
            .filter { cutoff in
                guard let clearedAtCutoff else { return true }
                return cutoff.createdAt > clearedAtCutoff
            }
            .filter { !$0.isDeletedForMe(currentUserId) }
    }

    /// Merges the authoritative server snapshot with any optimistic messages that
    /// haven't been confirmed by the listener yet, matched by id (the client
    /// generates the message id up front and uses it as the Firestore doc id, so
    /// once the server copy arrives it always has the same id as the local one).
    private func reconcile(with serverMessages: [Message]) {
        let serverIds = Set(serverMessages.map(\.id))
        let stillPending = messages.filter { $0.status == .sending && !serverIds.contains($0.id) }
        messages = (serverMessages + stillPending).sorted { $0.createdAt < $1.createdAt }
    }

    /// This chat screen is open and rendering these messages, so anything the other
    /// participant sent that isn't already marked read gets bumped forward:
    /// - sent -> delivered (their message reached this device)
    /// - delivered -> read (the recipient is actively looking at this conversation)
    /// Real "online delivery" would need a presence/Cloud Functions backend (Phase 1
    /// intentionally has neither), so both hops happen client-side, here, on receipt.
    private func advanceIncomingMessageStatuses(_ messages: [Message]) async {
        guard !currentUserId.isEmpty else { return }

        let toDeliver = messages.filter { $0.senderId != currentUserId && $0.status == .sent }.map(\.id)
        if !toDeliver.isEmpty {
            do {
                try await chatRepository.updateMessageStatuses(
                    conversationId: conversationId, messageIds: toDeliver, status: .delivered
                )
                // Without this pause, when the recipient already has the chat open
                // ("online"), the read-write below fires within milliseconds of this
                // one — both updates reach the server close enough together that the
                // sender's listener only ever gets invoked with the *final* state and
                // never renders the gray "delivered" double-tick at all, jumping
                // straight from one tick to blue. Give it a beat to actually land and
                // be observed as its own snapshot first.
                try? await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                // If this prints "Missing or insufficient permissions", your Firestore
                // security rules only allow a message's sender to update it — the
                // recipient needs write access to bump status too. See the rules
                // snippet in the chat notes.
                print("markDelivered error: \(error)")
            }
        }

        let toRead = messages.filter { $0.senderId != currentUserId && ($0.status == .sent || $0.status == .delivered) }.map(\.id)
        if !toRead.isEmpty {
            do {
                try await chatRepository.updateMessageStatuses(
                    conversationId: conversationId, messageIds: toRead, status: .read
                )
            } catch {
                print("markRead error: \(error)")
            }
        }
    }

    func stop() {
        observeTask?.cancel()
        conversationObserveTask?.cancel()
        typingObserveTask?.cancel()
        reachabilityCancellable?.cancel()

        stopTypingTask?.cancel()
        if isCurrentlyTyping {
            isCurrentlyTyping = false
            let uid = currentUserId
            let cid = conversationId
            let repository = chatRepository
            // Fire-and-forget: the view is going away, so this can't be awaited from
            // here, but leaving isTyping stuck at true would show "typing..." to the
            // other participant until the 8s staleness window clears it on its own.
            Task { try? await repository.setTyping(conversationId: cid, userId: uid, isTyping: false) }
        }
    }

    // MARK: - Typing

    /// Call on every keystroke in the composer. Writes `isTyping: true` once (not per
    /// keystroke) and resets a 4s idle timer that flips it back to `false` if the user
    /// stops typing without sending.
    func userIsTyping() {
        guard !currentUserId.isEmpty else { return }

        if !isCurrentlyTyping {
            isCurrentlyTyping = true
            let uid = currentUserId
            let cid = conversationId
            Task { try? await self.chatRepository.setTyping(conversationId: cid, userId: uid, isTyping: true) }
        }

        stopTypingTask?.cancel()
        stopTypingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.clearTyping()
        }
    }

    /// Immediately clears typing state — called on send, and on idle-timeout above.
    func clearTyping() async {
        stopTypingTask?.cancel()
        guard isCurrentlyTyping, !currentUserId.isEmpty else { return }
        isCurrentlyTyping = false
        try? await chatRepository.setTyping(conversationId: conversationId, userId: currentUserId, isTyping: false)
    }

    // MARK: - Search

    /// Client-side substring search over the messages already loaded for this chat
    /// (text messages only — media has no text to match). Good enough for a single
    /// conversation's history; a cross-conversation/full-history search would need a
    /// dedicated index (Firestore has no native full-text search — see the search note
    /// on `UserRepository.searchUsers`).
    private func runSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            searchMatchIds = []
            currentSearchMatchIndex = 0
            return
        }

        let previousMatchId = currentSearchMatchId
        searchMatchIds = messages
            .filter { $0.type == .text && ($0.text?.lowercased().contains(trimmed) ?? false) }
            .map(\.id)

        // Keep the user's place in the results if their current match is still present
        // (e.g. a new message arrived while they were paging through matches);
        // otherwise land on the most recent match.
        if let previousMatchId, let index = searchMatchIds.firstIndex(of: previousMatchId) {
            currentSearchMatchIndex = index
        } else {
            currentSearchMatchIndex = max(0, searchMatchIds.count - 1)
        }
    }

    func goToNextMatch() {
        guard !searchMatchIds.isEmpty else { return }
        currentSearchMatchIndex = (currentSearchMatchIndex + 1) % searchMatchIds.count
    }

    func goToPreviousMatch() {
        guard !searchMatchIds.isEmpty else { return }
        currentSearchMatchIndex = (currentSearchMatchIndex - 1 + searchMatchIds.count) % searchMatchIds.count
    }

    func clearSearch() {
        searchQuery = ""
    }

    /// Uploads a picked/recorded photo, video, or voice clip and sends it as a message.
    /// Mirrors sendDraft()'s optimistic-echo/failure pattern, plus a progress readout
    /// for the upload itself since media transfers can take a few seconds.
    func sendMedia(senderId: String, data: Data, kind: MediaKind, duration: Double? = nil) async {
        let type: MessageType = {
            switch kind {
            case .image: return .image
            case .video: return .video
            case .audio: return .audio
            }
        }()

        var message = Message.mediaDraft(
            conversationId: conversationId,
            senderId: senderId,
            type: type,
            duration: duration,
            replyTo: replyingTo,
            replySenderName: replyingTo.map { replySenderLabel(for: $0, currentUserId: senderId) }
        )
        replyingTo = nil
        messages.append(message)
        await localStore.upsertMessages([message], conversationId: conversationId)
        uploadProgress[message.id] = 0

        // Media isn't queued for background retry the way text is (that would mean
        // holding raw photo/video/audio bytes in the SwiftData cache, which the
        // blueprint calls out as a BackgroundTasks-driven upload queue for later —
        // see §6). For now, offline just fails fast instead of hanging on a request
        // that can't succeed.
        guard Reachability.shared.isOnline else {
            message.status = .failed
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
            }
            await localStore.updateMessageStatus(id: message.id, status: .failed)
            uploadProgress[message.id] = nil
            return
        }

        do {
            let result = try await mediaRepository.upload(data: data, kind: kind) { [weak self] fraction in
                self?.uploadProgress[message.id] = fraction
            }
            message.mediaURL = result.url
            message.duration = message.duration ?? result.duration
            message.status = .sent
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
            }
            try await chatRepository.sendMessage(message, memberIds: conversation?.memberIds ?? [])
            await localStore.updateMessageStatus(id: message.id, status: .sent)
        } catch {
            print("sendMedia error: \(error)")
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .failed
            }
            await localStore.updateMessageStatus(id: message.id, status: .failed)
        }
        uploadProgress[message.id] = nil
    }

    func sendDraft(senderId: String) async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        draftText = ""
        isSending = true
        defer { isSending = false }
        await clearTyping()

        let message = Message.draft(
            conversationId: conversationId,
            senderId: senderId,
            text: trimmed,
            replyTo: replyingTo,
            replySenderName: replyingTo.map { replySenderLabel(for: $0, currentUserId: senderId) }
        )
        replyingTo = nil

        // Optimistic local echo: show it instantly instead of waiting on the realtime
        // listener round-trip. Also persisted to SwiftData right away so it survives an
        // app kill before the Firestore write lands — or before it even gets a chance to
        // run, if we're offline.
        messages.append(message)
        await localStore.upsertMessages([message], conversationId: conversationId)

        guard Reachability.shared.isOnline else {
            // Leave it at "sending" — the reachability observer in start() retries it
            // as soon as the network comes back.
            return
        }

        do {
            try await chatRepository.sendMessage(message, memberIds: conversation?.memberIds ?? [])
            await localStore.updateMessageStatus(id: message.id, status: .sent)
        } catch {
            print("sendMessage error: \(error)")
            // Reflect the failure on the bubble itself rather than losing it silently.
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index].status = .failed
            }
            await localStore.updateMessageStatus(id: message.id, status: .failed)
            // Restore the draft so the user doesn't lose what they typed.
            draftText = trimmed
        }
    }
}
