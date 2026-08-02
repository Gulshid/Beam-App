import SwiftUI

/// Single row in a conversation list — shared by the Chats tab (all conversations)
/// and the Groups tab (group conversations only) so both render identically.
struct ConversationRowView: View {
    let title: String
    let preview: String
    let updatedAt: Date
    let unreadCount: Int
    let isTyping: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.tint.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(title.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))

                if isTyping {
                    Text("typing…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text(preview)
                        .font(.subheadline)
                        .fontWeight(unreadCount > 0 ? .semibold : .regular)
                        .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(updatedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                    .fontWeight(unreadCount > 0 ? .semibold : .regular)

                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .frame(minWidth: 20)
                        .background(Color.accentColor, in: Capsule())
                } else {
                    // Reserves the badge's vertical space so rows don't jump height
                    // as unreadCount toggles between 0 and >0.
                    Color.clear.frame(width: 1, height: 18)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
