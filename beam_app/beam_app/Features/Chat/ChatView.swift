import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatViewModel

    init(conversationId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == appState.currentUser?.id
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

            HStack(spacing: 12) {
                TextField("Message", text: $viewModel.draftText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))

                Button {
                    Task {
                        guard let uid = appState.currentUser?.id else { return }
                        await viewModel.sendDraft(senderId: uid)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
                .disabled(viewModel.draftText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
            }
            .padding(12)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
