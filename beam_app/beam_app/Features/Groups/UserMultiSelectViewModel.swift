import Foundation

/// Shared search + multi-select logic for "who do you want to add" flows — used both
/// when creating a new group and when adding members to an existing one.
@MainActor
final class UserMultiSelectViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published private(set) var searchResults: [AppUser] = []
    @Published private(set) var selectedUsers: [AppUser] = []
    @Published private(set) var isSearching = false

    private let userRepository: UserRepository
    private let currentUserId: String?
    /// Users who should never show up in results (e.g. already in the group).
    private let excludedIds: Set<String>

    init(
        currentUserId: String?,
        excludedIds: Set<String> = [],
        userRepository: UserRepository = FirestoreUserRepository()
    ) {
        self.currentUserId = currentUserId
        self.excludedIds = excludedIds
        self.userRepository = userRepository
    }

    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await userRepository.searchUsers(matching: searchQuery, excluding: currentUserId)
            let hiddenIds = excludedIds.union(selectedUsers.map(\.id))
            searchResults = results.filter { !hiddenIds.contains($0.id) }
        } catch {
            print("search error: \(error)")
            searchResults = []
        }
    }

    func toggle(_ user: AppUser) {
        if let index = selectedUsers.firstIndex(where: { $0.id == user.id }) {
            selectedUsers.remove(at: index)
        } else {
            selectedUsers.append(user)
        }
        searchResults.removeAll { $0.id == user.id }
    }

    func remove(_ user: AppUser) {
        selectedUsers.removeAll { $0.id == user.id }
    }
}
