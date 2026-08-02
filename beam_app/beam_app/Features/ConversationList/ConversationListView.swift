import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingNewChat = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.conversations.isEmpty {
                    ContentUnavailableView(
                        "No conversations yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Tap the compose button to start a chat.")
                    )
                } else {
                    List(viewModel.conversations) { conversation in
                        NavigationLink(value: conversation.id) {
                            ConversationRow(
                                title: viewModel.displayTitle(for: conversation, currentUserId: appState.currentUser?.id ?? ""),
                                preview: conversation.lastMessagePreview ?? "No messages yet",
                                updatedAt: conversation.updatedAt
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: String.self) { conversationId in
                ChatView(conversationId: conversationId)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out", role: .destructive) {
                        appState.signOut()
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatSearchView(currentUserId: appState.currentUser?.id) { selectedUser in
                    Task {
                        guard let currentUserId = appState.currentUser?.id else { return }
                        if let conversationId = await viewModel.startConversation(with: selectedUser, currentUserId: currentUserId) {
                            showingNewChat = false
                            navigationPath.append(conversationId)
                        }
                    }
                }
            }
        }
        .task {
            if let uid = appState.currentUser?.id {
                viewModel.start(currentUserId: uid)
            }
        }
        .onDisappear { viewModel.stop() }
    }
}

private struct ConversationRow: View {
    let title: String
    let preview: String
    let updatedAt: Date

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.tint.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(title.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(updatedAt, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AppState())
}
