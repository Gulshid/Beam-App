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

    let conversationId: String
    private let chatRepository: ChatRepository
    private let mediaRepository: MediaRepository
    private let userRepository: UserRepository
    private let localStore: SwiftDataStore
    private var observeTask: Task<Void, Never>?
    private var conversationObserveTask: Task<Void, Never>?
    private var reachabilityCancellable: AnyCancellable?
    private var currentUserId: String = ""
    private var wasOffline = false
    /// uid -> displayName, populated for group members only (used for the sender label
    /// shown above incoming bubbles — direct chats don't need it).
    private var memberNames: [String: String] = [:]

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

    /// - Parameter currentUserId: needed so we know which messages are "incoming" and can be
    ///   advanced from sent -> delivered -> read as this device receives/views them.
    func start(currentUserId: String) {
        self.currentUserId = currentUserId

        // Cold-launch / offline: paint whatever's cached instantly, before Firestore's
        // listener has had a chance to (re)connect.
        Task {
            let cached = await localStore.fetchCachedMessages(conversationId: conversationId)
            if messages.isEmpty && !cached.isEmpty {
                messages = cached
            }
        }

        observeTask?.cancel()
        observeTask = Task {
            for await updated in chatRepository.observeMessages(conversationId: conversationId) {
                self.reconcile(with: updated)
                await self.localStore.upsertMessages(updated, conversationId: conversationId)
                await self.advanceIncomingMessageStatuses(updated)
            }
        }

        conversationObserveTask?.cancel()
        conversationObserveTask = Task {
            for await updated in chatRepository.observeConversation(conversationId: conversationId) {
                guard let updated else { continue }
                self.conversation = updated
                await self.updateTitleAndMemberNames(updated, currentUserId: currentUserId)
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
                try await chatRepository.sendMessage(message)
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
        reachabilityCancellable?.cancel()
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

        var message = Message.mediaDraft(conversationId: conversationId, senderId: senderId, type: type, duration: duration)
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
            try await chatRepository.sendMessage(message)
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

        let message = Message.draft(conversationId: conversationId, senderId: senderId, text: trimmed)

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
            try await chatRepository.sendMessage(message)
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
