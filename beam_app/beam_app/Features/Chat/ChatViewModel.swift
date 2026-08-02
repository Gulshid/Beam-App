import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published var draftText = ""
    @Published private(set) var isSending = false

    let conversationId: String
    private let chatRepository: ChatRepository
    private var observeTask: Task<Void, Never>?
    private var currentUserId: String = ""

    init(conversationId: String, chatRepository: ChatRepository = FirestoreChatRepository()) {
        self.conversationId = conversationId
        self.chatRepository = chatRepository
    }

    /// - Parameter currentUserId: needed so we know which messages are "incoming" and can be
    ///   advanced from sent -> delivered -> read as this device receives/views them.
    func start(currentUserId: String) {
        self.currentUserId = currentUserId
        observeTask?.cancel()
        observeTask = Task {
            for await updated in chatRepository.observeMessages(conversationId: conversationId) {
                self.messages = updated
                await self.advanceIncomingMessageStatuses(updated)
            }
        }
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
            try? await chatRepository.updateMessageStatuses(
                conversationId: conversationId, messageIds: toDeliver, status: .delivered
            )
        }

        let toRead = messages.filter { $0.senderId != currentUserId && ($0.status == .sent || $0.status == .delivered) }.map(\.id)
        if !toRead.isEmpty {
            try? await chatRepository.updateMessageStatuses(
                conversationId: conversationId, messageIds: toRead, status: .read
            )
        }
    }

    func stop() {
        observeTask?.cancel()
    }

    func sendDraft(senderId: String) async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        draftText = ""
        isSending = true
        defer { isSending = false }

        let message = Message.draft(conversationId: conversationId, senderId: senderId, text: trimmed)

        do {
            try await chatRepository.sendMessage(message)
        } catch {
            print("sendMessage error: \(error)")
            // Restore the draft so the user doesn't lose what they typed.
            draftText = trimmed
        }
    }
}
