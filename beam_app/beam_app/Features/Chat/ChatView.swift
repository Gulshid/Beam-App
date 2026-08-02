import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var voiceRecorderVM = VoiceRecorderViewModel()
    @ObservedObject private var reachability = Reachability.shared
    @State private var showMediaPicker = false
    @State private var isRecording = false
    @State private var isSearching = false

    init(conversationId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
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
                                isCurrentSearchMatch: message.id == viewModel.currentSearchMatchId
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
            }

            if isSearching {
                Divider()
                MessageSearchBarView(viewModel: viewModel) {
                    isSearching = false
                }
            }

            Divider()

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
