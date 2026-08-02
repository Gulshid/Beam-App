import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var voiceRecorderVM = VoiceRecorderViewModel()
    @ObservedObject private var reachability = Reachability.shared
    @State private var showMediaPicker = false
    @State private var isRecording = false

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
                                senderName: viewModel.senderName(for: message)
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
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
