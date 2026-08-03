import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    var uploadProgress: Double? = nil
    /// Sender's display name — passed only for group chats, and only rendered above
    /// incoming bubbles (own messages don't need a "you" label).
    var senderName: String? = nil
    /// Active in-chat search term, if any — matched substrings get highlighted inline.
    var searchQuery: String = ""
    /// True when this bubble is the currently-focused search result, so it can be
    /// picked out from other matches (e.g. "3 of 7") with an outline.
    var isCurrentSearchMatch: Bool = false

    var myReaction: String? = nil
    var reactionSummary: [(emoji: String, count: Int)] = []

    var onReply: () -> Void = {}
    var onDeleteForMe: () -> Void = {}
    var onDeleteForEveryone: () -> Void = {}
    var onReact: (String) -> Void = { _ in }
    /// Called when the quoted-reply preview inside this bubble is tapped, with the
    /// id of the original message it's quoting — the chat view scrolls to it.
    var onTapQuotedReply: (String) -> Void = { _ in }

    @State private var isPresentingFullScreenImage = false
    @State private var isPresentingVideoPlayer = false
    /// Live horizontal offset while swiping this bubble right-to-reply.
    @State private var swipeOffset: CGFloat = 0
    private let swipeToReplyThreshold: CGFloat = 60

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 40) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser, let senderName {
                    Text(senderName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                if message.isDeletedForEveryone {
                    deletedContent
                } else {
                    VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                        if let replyId = message.replyToMessageId {
                            quotedReplyPreview(replyId: replyId)
                        }
                        bubbleContent
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .overlay {
                        if isCurrentSearchMatch {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(.yellow, lineWidth: 2)
                        }
                    }
                    .contextMenu { contextMenuItems }
                }

                if !reactionSummary.isEmpty {
                    reactionPill
                }

                HStack(spacing: 4) {
                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }
            .offset(x: swipeOffset)
            .overlay(alignment: isFromCurrentUser ? .trailing : .leading) {
                // The little reply arrow that grows in as you drag — mirrors the
                // WhatsApp swipe-to-reply affordance.
                if !message.isDeletedForEveryone {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .foregroundStyle(.secondary)
                        .opacity(min(1, abs(swipeOffset) / swipeToReplyThreshold))
                        .offset(x: isFromCurrentUser ? 28 : -28)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !message.isDeletedForEveryone else { return }
                        // Only allow the "swipe toward the reply arrow" direction —
                        // right for incoming bubbles, left for your own — so this
                        // never fights with the ScrollView's vertical scrolling or
                        // reads as an accidental drag the other way.
                        let translation = value.translation.width
                        let allowed = isFromCurrentUser ? min(0, translation) : max(0, translation)
                        swipeOffset = allowed / 2.2
                    }
                    .onEnded { value in
                        guard !message.isDeletedForEveryone else { return }
                        if abs(swipeOffset) > swipeToReplyThreshold / 2.2 {
                            onReply()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            swipeOffset = 0
                        }
                    }
            )

            if !isFromCurrentUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var deletedContent: some View {
        Label("This message was deleted", systemImage: "nosign")
            .font(.subheadline)
            .italic()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            // The placeholder itself had no contextMenu, so once a message was
            // deleted for everyone there was no way left to also clear it out of
            // your own view — it would sit there as "This message was deleted"
            // forever. Reply/copy/react don't make sense here (there's no content
            // left), but "delete for me" still does.
            .contextMenu {
                Button(role: .destructive) {
                    onDeleteForMe()
                } label: {
                    Label("Delete for me", systemImage: "trash")
                }
            }
    }

    @ViewBuilder
    private func quotedReplyPreview(replyId: String) -> some View {
        Button {
            onTapQuotedReply(replyId)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(message.replyPreviewSenderName ?? "Someone")
                    .font(.caption.weight(.semibold))
                Text(message.replyPreviewText ?? "")
                    .font(.caption)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(isFromCurrentUser ? 0.15 : 0.06), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                // GeometryReader pins this to the label's *actual* measured height.
                // A bare Rectangle() here has no intrinsic height, so — since this
                // bubble sits inside a ScrollView, which proposes unbounded height
                // along the scroll axis — it was expanding to fill all remaining
                // scroll space instead of just hugging the quoted-preview row.
                GeometryReader { geo in
                    Rectangle()
                        .fill(isFromCurrentUser ? .white : Color.accentColor)
                        .frame(width: 3, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var reactionPill: some View {
        HStack(spacing: 2) {
            ForEach(reactionSummary, id: \.emoji) { entry in
                Text(entry.count > 1 ? "\(entry.emoji)\(entry.count)" : entry.emoji)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(.secondarySystemBackground), in: Capsule())
        .overlay(Capsule().stroke(.separator, lineWidth: 0.5))
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onReply()
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }

        if message.type == .text, let text = message.text {
            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }

        Menu {
            ForEach(MessageReactionPalette.quickReactions, id: \.self) { emoji in
                Button {
                    onReact(emoji)
                } label: {
                    Text(emoji)
                }
            }
        } label: {
            Label("React", systemImage: "face.smiling")
        }

        Button(role: .destructive) {
            onDeleteForMe()
        } label: {
            Label("Delete for me", systemImage: "trash")
        }

        // Only the sender can pull a message back from everyone else's copy of the
        // conversation — enforced again server-side in the security rules.
        if isFromCurrentUser {
            Button(role: .destructive) {
                onDeleteForEveryone()
            } label: {
                Label("Delete for everyone", systemImage: "trash.fill")
            }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.type {
        case .text:
            highlightedText(message.text ?? "")
        case .image:
            imageContent
        case .video:
            videoContent
        case .audio:
            audioContent
        }
    }

    /// Plain `Text` when there's no active search, otherwise an `AttributedString`
    /// with every case-insensitive occurrence of `searchQuery` given a highlight
    /// background — same idea as Safari/Mail's "find in page" highlighting.
    private func highlightedText(_ text: String) -> Text {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return Text(text) }

        var attributed = AttributedString(text)
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(of: trimmedQuery, options: .caseInsensitive) {
            attributed[range].backgroundColor = .yellow.opacity(0.6)
            attributed[range].foregroundColor = .black
            searchStart = range.upperBound
        }
        return Text(attributed)
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
