import Foundation

@MainActor
final class GroupCreationViewModel: ObservableObject {
    @Published private(set) var isCreating = false

    private let chatRepository: ChatRepository

    init(chatRepository: ChatRepository = FirestoreChatRepository()) {
        self.chatRepository = chatRepository
    }

    func createGroup(title: String, memberIds: [String]) async -> String? {
        isCreating = true
        defer { isCreating = false }

        do {
            return try await chatRepository.createGroupConversation(title: title, memberIds: memberIds)
        } catch {
            print("createGroup error: \(error)")
            return nil
        }
    }
}
