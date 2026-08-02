import SwiftUI

/// Reusable "search people, tap to select multiple" list — a chips row for the current
/// selection plus a searchable results list below it. Used by both group creation and
/// "add members to an existing group".
struct UserMultiSelectView: View {
    @ObservedObject var viewModel: UserMultiSelectViewModel
    var emptyStateTitle = "Add people"
    var emptyStateDescription = "Search for people to add."

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.selectedUsers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.selectedUsers) { user in
                            SelectedUserChip(user: user) {
                                viewModel.remove(user)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            List(viewModel.searchResults) { user in
                Button {
                    viewModel.toggle(user)
                } label: {
                    HStack {
                        Circle()
                            .fill(.tint.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(user.displayName.prefix(1).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.tint)
                            }
                        Text(user.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.isSearching {
                    ProgressView()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                } else if viewModel.selectedUsers.isEmpty && viewModel.searchQuery.isEmpty {
                    ContentUnavailableView(
                        emptyStateTitle,
                        systemImage: "person.2",
                        description: Text(emptyStateDescription)
                    )
                }
            }
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search by name")
        .onChange(of: viewModel.searchQuery) {
            Task { await viewModel.search() }
        }
    }
}

private struct SelectedUserChip: View {
    let user: AppUser
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(user.displayName)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.tint.opacity(0.15), in: Capsule())
    }
}
