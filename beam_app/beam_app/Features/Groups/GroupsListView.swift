import SwiftUI

/// The Groups tab. Reuses `ConversationListViewModel` (it already streams every
/// conversation the user belongs to) and just filters down to `.group` — a second,
/// independent listener rather than sharing state with the Chats tab, same tradeoff
/// the typing-indicator observers already make elsewhere in this list (see its doc
/// comment): simplest thing that works at this app's scale.
struct GroupsListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var showingNewGroup = false
    @State private var navigationPath = NavigationPath()

    private var groupConversations: [Conversation] {
        viewModel.conversations.filter { $0.type == .group }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if groupConversations.isEmpty {
                    ContentUnavailableView(
                        "No groups yet",
                        systemImage: "person.3",
                        description: Text("Tap the compose button to start a group.")
                    )
                } else {
                    List(groupConversations) { conversation in
                        NavigationLink(value: conversation.id) {
                            ConversationRowView(
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
            .navigationTitle("Groups")
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
                    Button {
                        showingNewGroup = true
                    } label: {
                        Image(systemName: "square.and.pencil")
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

#Preview {
    GroupsListView()
        .environmentObject(AppState())
}
