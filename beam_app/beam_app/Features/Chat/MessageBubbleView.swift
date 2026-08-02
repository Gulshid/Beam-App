import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    var uploadProgress: Double? = nil

    @State private var isPresentingFullScreenImage = false
    @State private var isPresentingVideoPlayer = false

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 40) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                bubbleContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)

                HStack(spacing: 4) {
                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }

            if !isFromCurrentUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.type {
        case .text:
            Text(message.text ?? "")
        case .image:
            imageContent
        case .video:
            videoContent
        case .audio:
            audioContent
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let mediaURL = message.mediaURL, let url = URL(string: mediaURL) {
            Button {
                isPresentingFullScreenImage = true
            } label: {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "photo").imageScale(.large)
                    default:
                        ProgressView()
                    }
                }
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $isPresentingFullScreenImage) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                }
                .onTapGesture { isPresentingFullScreenImage = false }
            }
        } else {
            uploadingPlaceholder(icon: "photo")
        }
    }

    @ViewBuilder
    private var videoContent: some View {
        if let mediaURL = message.mediaURL, let url = URL(string: mediaURL) {
            Button {
                isPresentingVideoPlayer = true
            } label: {
                ZStack {
                    Rectangle()
                        .fill(.black.opacity(0.85))
                        .frame(width: 220, height: 220)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $isPresentingVideoPlayer) {
                VideoMessagePlayerView(url: url)
            }
        } else {
            uploadingPlaceholder(icon: "video")
        }
    }

    @ViewBuilder
    private var audioContent: some View {
        if let mediaURL = message.mediaURL, let url = URL(string: mediaURL) {
            AudioMessageView(url: url, duration: message.duration ?? 0, tint: isFromCurrentUser ? .white : .accentColor)
        } else {
            uploadingPlaceholder(icon: "waveform")
        }
    }

    /// Shown while a photo/video/voice message's Cloudinary upload is still in flight
    /// (mediaURL is nil until the upload resolves — see ChatViewModel.sendMedia).
    @ViewBuilder
    private func uploadingPlaceholder(icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
            if let uploadProgress {
                ProgressView(value: uploadProgress)
                    .frame(width: 100)
            } else {
                ProgressView()
            }
        }
        .frame(width: 120, height: 80)
    }

    private var bubbleColor: Color {
        isFromCurrentUser ? .accentColor : Color(.secondarySystemBackground)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .sent:
            singleCheck
                .foregroundStyle(.secondary)
        case .delivered:
            doubleCheck
                .foregroundStyle(.secondary)
        case .read:
            doubleCheck
                .foregroundStyle(.blue)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    /// Single tick: message written to the server.
    private var singleCheck: some View {
        Image(systemName: "checkmark")
            .font(.caption2)
    }

    /// WhatsApp-style overlapping double tick: delivered (gray) or read (blue).
    /// SF Symbols has no built-in "double checkmark", so two checkmarks are
    /// offset to overlap, matching the familiar messaging-app convention.
    private var doubleCheck: some View {
        ZStack {
            Image(systemName: "checkmark")
                .font(.caption2)
                .offset(x: -3)
            Image(systemName: "checkmark")
                .font(.caption2)
                .offset(x: 3)
        }
        .frame(width: 16)
    }
}

#Preview {
    VStack {
        MessageBubbleView(
            message: .draft(conversationId: "c1", senderId: "me", text: "Hey! How's it going?"),
            isFromCurrentUser: true
        )
        MessageBubbleView(
            message: .draft(conversationId: "c1", senderId: "them", text: "Pretty good, working on the chat app 🎉"),
            isFromCurrentUser: false
        )
    }
    .padding()
}
