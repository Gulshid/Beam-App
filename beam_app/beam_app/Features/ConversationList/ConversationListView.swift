import SwiftUI

struct ConversationListView: View {
    enum ChatFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
    @State private var navigationPath = NavigationPath()
    @State private var conversationPendingDelete: Conversation?
    @State private var selectedFilter: ChatFilter = .all

    private var currentUserId: String { appState.currentUser?.id ?? "" }

    private var filteredConversations: [Conversation] {
        switch selectedFilter {
        case .all:
            return viewModel.conversations
        case .unread:
            return viewModel.conversations.filter { $0.unreadCount(for: currentUserId) > 0 }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                filterBar

                Group {
                    if filteredConversations.isEmpty {
                        if selectedFilter == .unread {
                            ContentUnavailableView(
                                "No unread chats",
                                systemImage: "checkmark.circle",
                                description: Text("You're all caught up.")
                            )
                        } else {
                            ContentUnavailableView(
                                "No conversations yet",
                                systemImage: "bubble.left.and.bubble.right",
                                description: Text("Tap the compose button to start a chat.")
                            )
                        }
                    } else {
                        List(filteredConversations) { conversation in
                            NavigationLink(value: conversation.id) {
                                ConversationRowView(
                                    title: viewModel.displayTitle(for: conversation, currentUserId: currentUserId),
                                    preview: conversation.lastMessagePreview ?? "No messages yet",
                                    updatedAt: conversation.updatedAt,
                                    unreadCount: conversation.unreadCount(for: currentUserId),
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
            }
            .navigationTitle("Chats")
            .navigationDestination(for: String.self) { conversationId in
                ChatView(conversationId: conversationId)
            }
            .navigationDestination(for: GroupInfoRoute.self) { route in
                GroupInfoView(
                    conversationId: route.conversationId,
                    currentUserId: currentUserId
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
                GroupCreationView(currentUserId: currentUserId) { conversationId in
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

    /// WhatsApp-style "All / Unread" pill selector, pinned above the list.
    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(ChatFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedFilter = filter }
                } label: {
                    HStack(spacing: 5) {
                        Text(filter.rawValue)
                        if filter == .unread {
                            let count = viewModel.conversations.filter { $0.unreadCount(for: currentUserId) > 0 }.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(selectedFilter == filter ? Color.accentColor : .white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        selectedFilter == filter ? Color.white : Color.accentColor,
                                        in: Capsule()
                                    )
                            }
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        selectedFilter == filter ? Color.accentColor : Color(.secondarySystemBackground),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AppState())
}
