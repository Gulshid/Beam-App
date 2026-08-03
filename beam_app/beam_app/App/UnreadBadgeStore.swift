import Foundation

/// Tracks the current user's total unread-conversation count, purely so the
/// custom tab bar can show a live badge on the "Chats" tab without
/// `MainTabView` needing to own (or duplicate) `ConversationListViewModel`'s
/// full conversation-list logic.
///
/// Deliberately minimal: same `observeConversations` stream the chat list
/// already uses, reduced down to a single count.
@MainActor
final class UnreadBadgeStore: ObservableObject {
    @Published private(set) var totalUnreadCount = 0

    private let chatRepository: ChatRepository
    private var observeTask: Task<Void, Never>?

    init(chatRepository: ChatRepository = FirestoreChatRepository()) {
        self.chatRepository = chatRepository
    }

    func start(currentUserId: String) {
        guard !currentUserId.isEmpty else { return }
        observeTask?.cancel()
        observeTask = Task {
            for await conversations in chatRepository.observeConversations(forUserId: currentUserId) {
                let count = conversations.filter { $0.unreadCount(for: currentUserId) > 0 }.count
                self.totalUnreadCount = count
            }
        }
    }

    func stop() {
        observeTask?.cancel()
        observeTask = nil
    }
}
