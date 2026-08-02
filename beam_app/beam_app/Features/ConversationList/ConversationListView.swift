import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
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
                                updatedAt: conversation.updatedAt,
                                unreadCount: conversation.unreadCount(for: appState.currentUser?.id ?? ""),
                                isTyping: viewModel.typingConversationIds.contains(conversation.id)
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
            .navigationDestination(for: GroupInfoRoute.self) { route in
                GroupInfoView(
                    conversationId: route.conversationId,
                    currentUserId: appState.currentUser?.id ?? ""
                ) {
                    // Leaving a group makes both the info screen and the chat thread
                    // behind it invalid, so pop all the way back to the list.
                    navigationPath = NavigationPath()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingNewChat = true
                        } label: {
                            Label("New Chat", systemImage: "person")
                        }
                        Button {
                            showingNewGroup = true
                        } label: {
                            Label("New Group", systemImage: "person.3")
                        }
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
            .sheet(isPresented: $showingNewGroup) {
                GroupCreationView(currentUserId: appState.currentUser?.id ?? "") { conversationId in
                    showingNewGroup = false
                    navigationPath.append(conversationId)
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
    let unreadCount: Int
    let isTyping: Bool

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

                if isTyping {
                    Text("typing…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(preview)
                        .font(.subheadline)
                        .fontWeight(unreadCount > 0 ? .semibold : .regular)
                        .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(updatedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                    .fontWeight(unreadCount > 0 ? .semibold : .regular)

                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(minWidth: 20)
                        .background(Color.accentColor, in: Capsule())
                } else {
                    // Reserves the badge's vertical space so rows don't jump height
                    // as unreadCount toggles between 0 and >0.
                    Color.clear.frame(width: 1, height: 18)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AppState())
}
