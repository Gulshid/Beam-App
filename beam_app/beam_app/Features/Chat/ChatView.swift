import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var voiceRecorderVM = VoiceRecorderViewModel()
    @ObservedObject private var reachability = Reachability.shared
    @State private var showMediaPicker = false
    @State private var isRecording = false
    @State private var isSearching = false

    /// Set from Settings > Chats > Wallpaper. Empty string means "use the default
    /// system background" rather than any particular color.
    @AppStorage(SettingsKeys.chatWallpaperHex) private var chatWallpaperHex = ""

    private var wallpaperBackground: Color {
        chatWallpaperHex.isEmpty ? Color(.systemBackground) : Color(hex: chatWallpaperHex).opacity(0.18)
    }

    init(conversationId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }

    /// Groups a message's raw uid->emoji reactions map into the (emoji, count)
    /// pairs the bubble's reaction pill displays, most-used emoji first.
    private func reactionSummary(for message: Message) -> [(emoji: String, count: Int)] {
        guard let reactions = message.reactions, !reactions.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for emoji in reactions.values { counts[emoji, default: 0] += 1 }
        return counts.map { (emoji: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    /// Shown above the composer once the user has swiped/long-pressed "Reply" on a
    /// bubble — mirrors the standard "replying to ..." bar with a way to back out.
    private func replyPreviewBar(_ message: Message) -> some View {
        HStack(spacing: 8) {
            // Fixed height, not just fixed width — a bare Rectangle() has no
            // intrinsic height, so it was expanding to fill flexible vertical
            // space in the outer VStack (it sits alongside the ScrollView, and
            // both were greedily competing for the remaining height). Pinning
            // it to a concrete height keeps it just as tall as the text beside it.
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.replySenderLabel(for: message, currentUserId: appState.currentUser?.id ?? ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(Message.previewSnippet(for: message))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                viewModel.cancelReply()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !reachability.isOnline {
                Text("Offline — messages will send once you're back online")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(.orange)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == appState.currentUser?.id,
                                uploadProgress: viewModel.uploadProgress[message.id],
                                senderName: viewModel.senderName(for: message),
                                searchQuery: viewModel.searchQuery,
                                isCurrentSearchMatch: message.id == viewModel.currentSearchMatchId,
                                myReaction: viewModel.myReaction(to: message, currentUserId: appState.currentUser?.id ?? ""),
                                reactionSummary: reactionSummary(for: message),
                                onReply: { viewModel.beginReply(to: message) },
                                onDeleteForMe: {
                                    Task { await viewModel.deleteForMe(message, currentUserId: appState.currentUser?.id ?? "") }
                                },
                                onDeleteForEveryone: {
                                    Task { await viewModel.deleteForEveryone(message, currentUserId: appState.currentUser?.id ?? "") }
                                },
                                onReact: { emoji in
                                    viewModel.react(to: message, emoji: emoji, currentUserId: appState.currentUser?.id ?? "")
                                },
                                onTapQuotedReply: { replyId in
                                    guard viewModel.message(withId: replyId) != nil else { return }
                                    withAnimation {
                                        proxy.scrollTo(replyId, anchor: .center)
                                    }
                                }
                            )
                            .id(message.id)
                        }

                        if !viewModel.typingUserNames.isEmpty {
                            TypingIndicatorView(names: viewModel.typingUserNames)
                                .id("typing-indicator")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    // Search is active — don't yank the view to the bottom out from
                    // under a match the user just navigated to.
                    guard viewModel.searchQuery.isEmpty else { return }
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.typingUserNames.isEmpty) {
                    guard !viewModel.typingUserNames.isEmpty, viewModel.searchQuery.isEmpty else { return }
                    withAnimation {
                        proxy.scrollTo("typing-indicator", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.currentSearchMatchId) {
                    guard let matchId = viewModel.currentSearchMatchId else { return }
                    withAnimation {
                        proxy.scrollTo(matchId, anchor: .center)
                    }
                }
                .background(wallpaperBackground)
            }

            if isSearching {
                Divider()
                MessageSearchBarView(viewModel: viewModel) {
                    isSearching = false
                }
            }

            Divider()

            if let replyingTo = viewModel.replyingTo {
                replyPreviewBar(replyingTo)
                Divider()
            }

            if isRecording {
                VoiceRecorderView(
                    viewModel: voiceRecorderVM,
                    onFinish: { data, duration in
                        isRecording = false
                        Task {
                            guard let uid = appState.currentUser?.id else { return }
                            await viewModel.sendMedia(senderId: uid, data: data, kind: .audio, duration: duration)
                        }
                    },
                    onCancel: { isRecording = false }
                )
                .padding(12)
            } else {
                HStack(spacing: 12) {
                    Button {
                        showMediaPicker = true
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.title3)
                    }

                    TextField("Message", text: $viewModel.draftText, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
                        .onChange(of: viewModel.draftText) {
                            if !viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.userIsTyping()
                            }
                        }

                    if viewModel.draftText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            Task {
                                guard await VoiceRecorderViewModel.requestPermission() else { return }
                                isRecording = true
                                voiceRecorderVM.startRecording()
                            }
                        } label: {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 30))
                        }
                    } else {
                        Button {
                            Task {
                                guard let uid = appState.currentUser?.id else { return }
                                await viewModel.sendDraft(senderId: uid)
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                        }
                        .disabled(viewModel.isSending)
                    }
                }
                .padding(12)
            }
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation { isSearching.toggle() }
                    if !isSearching { viewModel.clearSearch() }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            if viewModel.conversation?.type == .group {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(value: GroupInfoRoute(conversationId: viewModel.conversationId)) {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
        .task { viewModel.start(currentUserId: appState.currentUser?.id ?? "") }
        .onDisappear { viewModel.stop() }
        .mediaPicker(isPresented: $showMediaPicker) { data, kind in
            Task {
                guard let uid = appState.currentUser?.id else { return }
                await viewModel.sendMedia(senderId: uid, data: data, kind: kind)
            }
        }
    }
}
