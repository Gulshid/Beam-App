import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
    @State private var navigationPath = NavigationPath()
    @State private var conversationPendingDelete: Conversation?

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
                            ConversationRowView(
                                title: viewModel.displayTitle(for: conversation, currentUserId: appState.currentUser?.id ?? ""),
                                preview: conversation.lastMessagePreview ?? "No messages yet",
                                updatedAt: conversation.updatedAt,
                                unreadCount: conversation.unreadCount(for: appState.currentUser?.id ?? ""),
                                isTyping: viewModel.typingConversationIds.contains(conversation.id)
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                conversationPendingDelete = conversation
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                conversationPendingDelete = conversation
                            } label: {
                                Label("Delete Chat", systemImage: "trash")
                            }
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
            .confirmationDialog(
                "Delete this chat?",
                isPresented: Binding(
                    get: { conversationPendingDelete != nil },
                    set: { if !$0 { conversationPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Chat", role: .destructive) {
                    guard let conversation = conversationPendingDelete,
                          let currentUserId = appState.currentUser?.id else { return }
                    Task {
                        await viewModel.deleteConversation(conversation.id, currentUserId: currentUserId)
                    }
                    conversationPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    conversationPendingDelete = nil
                }
            } message: {
                Text("This only removes it from your chat list. If they message you again, it'll come back.")
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

#Preview {
    ConversationListView()
        .environmentObject(AppState())
}
