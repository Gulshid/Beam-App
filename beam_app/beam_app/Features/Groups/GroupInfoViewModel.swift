import Foundation

@MainActor
final class GroupInfoViewModel: ObservableObject {
    @Published private(set) var conversation: Conversation?
    @Published private(set) var members: [AppUser] = []
    @Published var editableTitle = ""
    @Published private(set) var isSaving = false
    @Published private(set) var didLeave = false

    let conversationId: String
    let currentUserId: String
    private let chatRepository: ChatRepository
    private let userRepository: UserRepository
    private var observeTask: Task<Void, Never>?

    init(
        conversationId: String,
        currentUserId: String,
        chatRepository: ChatRepository = FirestoreChatRepository(),
        userRepository: UserRepository = FirestoreUserRepository()
    ) {
        self.conversationId = conversationId
        self.currentUserId = currentUserId
        self.chatRepository = chatRepository
        self.userRepository = userRepository
    }

    func start() {
        observeTask?.cancel()
        observeTask = Task {
            for await updated in chatRepository.observeConversation(conversationId: conversationId) {
                guard let updated else { continue }
                self.conversation = updated
                if self.editableTitle.isEmpty {
                    self.editableTitle = updated.title ?? ""
                }
                await self.loadMembers(updated.memberIds)
            }
        }
    }

    func stop() {
        observeTask?.cancel()
    }

    private func loadMembers(_ memberIds: [String]) async {
        var loaded: [AppUser] = []
        for uid in memberIds {
            if let user = try? await userRepository.fetchUser(uid: uid) {
                loaded.append(user)
            }
        }
        members = loaded.sorted { $0.displayName < $1.displayName }
    }

    func saveTitleIfChanged() async {
        let trimmed = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != conversation?.title else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await chatRepository.renameGroup(conversationId: conversationId, title: trimmed)
        } catch {
            print("renameGroup error: \(error)")
        }
    }

    func addMembers(_ users: [AppUser]) async {
        guard !users.isEmpty else { return }
        do {
            try await chatRepository.addMembers(conversationId: conversationId, memberIds: users.map(\.id))
        } catch {
            print("addMembers error: \(error)")
        }
    }

    func leaveGroup() async {
        do {
            try await chatRepository.removeMember(conversationId: conversationId, userId: currentUserId)
            didLeave = true
        } catch {
            print("leaveGroup error: \(error)")
        }
    }
}
