import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool

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
        case .image, .video, .audio:
            // Placeholder — Phase 2 replaces this with actual media rendering.
            Label(placeholderLabel, systemImage: placeholderIcon)
        }
    }

    private var placeholderLabel: String {
        switch message.type {
        case .image: return "Photo"
        case .video: return "Video"
        case .audio: return "Voice message"
        case .text: return ""
        }
    }

    private var placeholderIcon: String {
        switch message.type {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .text: return ""
        }
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
