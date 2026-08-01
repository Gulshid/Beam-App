import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published var draftText = ""
    @Published private(set) var isSending = false

    let conversationId: String
    private let chatRepository: ChatRepository
    private var observeTask: Task<Void, Never>?

    init(conversationId: String, chatRepository: ChatRepository = FirestoreChatRepository()) {
        self.conversationId = conversationId
        self.chatRepository = chatRepository
    }

    func start() {
        observeTask?.cancel()
        observeTask = Task {
            for await updated in chatRepository.observeMessages(conversationId: conversationId) {
                self.messages = updated
            }
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
