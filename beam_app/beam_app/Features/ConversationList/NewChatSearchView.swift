import SwiftUI

struct NewChatSearchView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @Environment(\.dismiss) private var dismiss
    let currentUserId: String?
    let onSelect: (AppUser) -> Void

    var body: some View {
        NavigationStack {
            List(viewModel.searchResults) { user in
                Button {
                    onSelect(user)
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
                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .foregroundStyle(.primary)
                            if let email = user.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isSearching {
                    ProgressView()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search by name")
            .onChange(of: viewModel.searchQuery) {
                Task { await viewModel.search(excluding: currentUserId) }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NewChatSearchView(currentUserId: "preview-uid") { _ in }
}
