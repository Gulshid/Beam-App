import Foundation

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var participantNames: [String: String] = [:]  // uid -> displayName cache
    @Published var searchQuery = ""
    @Published private(set) var searchResults: [AppUser] = []
    @Published var isSearching = false
    /// Ids of conversations where someone else is currently typing — drives the
    /// "typing…" row preview. Kept as a Set rather than per-row published state so a
    /// typing update in one conversation doesn't re-render every row.
    @Published private(set) var typingConversationIds: Set<String> = []

    private let chatRepository: ChatRepository
    private let userRepository: UserRepository
    private let localStore: SwiftDataStore
    private var observeTask: Task<Void, Never>?
    /// One listener per visible conversation — see `syncTypingObservers`.
    private var typingObserveTasks: [String: Task<Void, Never>] = [:]
    /// One listener per visible conversation — see `syncDeliveryObservers`.
    private var deliveryObserveTasks: [String: Task<Void, Never>] = [:]

    init(
        chatRepository: ChatRepository = FirestoreChatRepository(),
        userRepository: UserRepository = FirestoreUserRepository(),
        localStore: SwiftDataStore = .shared
    ) {
        self.chatRepository = chatRepository
        self.userRepository = userRepository
        self.localStore = localStore
    }

    func start(currentUserId: String) {
        // Cold-launch / offline: show cached conversations instantly, before Firestore's
        // listener has had a chance to (re)connect.
        Task {
            let cached = await localStore.fetchCachedConversations()
            if conversations.isEmpty && !cached.isEmpty {
                conversations = cached
                await loadParticipantNames(for: cached, currentUserId: currentUserId)
            }
        }

        observeTask?.cancel()
        observeTask = Task {
            for await updated in chatRepository.observeConversations(forUserId: currentUserId) {
                self.conversations = updated
                await self.localStore.upsertConversations(updated)
                await self.loadParticipantNames(for: updated, currentUserId: currentUserId)
                self.syncTypingObservers(for: updated, currentUserId: currentUserId)
                self.syncDeliveryObservers(for: updated, currentUserId: currentUserId)
            }
        }
    }

    func stop() {
        observeTask?.cancel()
        for task in typingObserveTasks.values { task.cancel() }
        typingObserveTasks.removeAll()
        for task in deliveryObserveTasks.values { task.cancel() }
        deliveryObserveTasks.removeAll()
    }

    /// Keeps one `observeTypingUsers` listener running per conversation currently in
    /// the list, adding listeners for newly-appeared conversations and tearing down
    /// ones for conversations that scrolled out of / left the list. One listener per
    /// row is fine at the scale this app targets (see blueprint's free-tier framing);
    /// a larger app would denormalize an "isAnyoneTyping" flag onto the conversation
    /// doc instead so the list only needs its existing single listener.
    private func syncTypingObservers(for conversations: [Conversation], currentUserId: String) {
        let currentIds = Set(conversations.map(\.id))

        for (id, task) in typingObserveTasks where !currentIds.contains(id) {
            task.cancel()
            typingObserveTasks.removeValue(forKey: id)
            typingConversationIds.remove(id)
        }

        for id in currentIds where typingObserveTasks[id] == nil {
            typingObserveTasks[id] = Task {
                for await typingIds in self.chatRepository.observeTypingUsers(conversationId: id, excluding: currentUserId) {
                    if typingIds.isEmpty {
                        self.typingConversationIds.remove(id)
                    } else {
                        self.typingConversationIds.insert(id)
                    }
                }
            }
        }
    }

    /// Keeps one `observeMessages` listener running per conversation currently in the
    /// list, bumping any incoming message still sitting at `.sent` to `.delivered`.
    /// This is deliberately separate from `ChatViewModel.advanceIncomingMessageStatuses`:
    /// that one only runs while the specific chat thread is open (and handles the
    /// delivered -> read hop too), which meant a message stayed on a single tick until
    /// the recipient opened that exact conversation — even with the app open and this
    /// list on screen. "Delivered" should mean "reached this device while the app is
    /// running", not "the recipient opened this exact thread", so it's tracked here
    /// too. Same one-listener-per-row tradeoff as `syncTypingObservers` above.
    private func syncDeliveryObservers(for conversations: [Conversation], currentUserId: String) {
        let currentIds = Set(conversations.map(\.id))

        for (id, task) in deliveryObserveTasks where !currentIds.contains(id) {
            task.cancel()
            deliveryObserveTasks.removeValue(forKey: id)
        }

        for id in currentIds where deliveryObserveTasks[id] == nil {
            deliveryObserveTasks[id] = Task {
                for await messages in self.chatRepository.observeMessages(conversationId: id) {
                    let toDeliver = messages
                        .filter { $0.senderId != currentUserId && $0.status == .sent }
                        .map(\.id)
                    guard !toDeliver.isEmpty else { continue }
                    do {
                        try await self.chatRepository.updateMessageStatuses(
                            conversationId: id, messageIds: toDeliver, status: .delivered
                        )
                    } catch {
                        print("markDelivered (list) error: \(error)")
                    }
                }
            }
        }
    }

    func displayTitle(for conversation: Conversation, currentUserId: String) -> String {
        if conversation.type == .group {
            return conversation.title ?? "Group Chat"
        }
        guard let otherId = conversation.otherMemberId(currentUserId: currentUserId) else {
            return "Conversation"
        }
        return participantNames[otherId] ?? "..."
    }

    func search(excluding currentUserId: String?) async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await userRepository.searchUsers(matching: searchQuery, excluding: currentUserId)
        } catch {
            print("search error: \(error)")
            searchResults = []
        }
    }

    func startConversation(with otherUser: AppUser, currentUserId: String) async -> String? {
        do {
            let conversationId = try await chatRepository.startDirectConversation(
                currentUserId: currentUserId,
                otherUserId: otherUser.id
            )
            participantNames[otherUser.id] = otherUser.displayName
            return conversationId
        } catch {
            print("startConversation error: \(error)")
            return nil
        }
    }

    private func loadParticipantNames(for conversations: [Conversation], currentUserId: String) async {
        let otherIds = Set(conversations.compactMap { $0.otherMemberId(currentUserId: currentUserId) })
        let missingIds = otherIds.subtracting(participantNames.keys)
        guard !missingIds.isEmpty else { return }

        for uid in missingIds {
            if let user = try? await userRepository.fetchUser(uid: uid) {
                participantNames[uid] = user.displayName
            }
        }
    }
}
