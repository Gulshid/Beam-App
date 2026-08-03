import SwiftUI

/// Avatar with a colored ring around it indicating status state — accent color for
/// "has something you haven't seen yet", gray once everything's been viewed. This is
/// a simplified single-ring indicator rather than WhatsApp's per-status segmented
/// ring (one arc per status); good enough to signal "new update" at a glance without
/// the extra geometry work a fully segmented ring would need.
struct StatusAvatarRing: View {
    enum RingState {
        case none
        case unviewed
        case viewed
    }

    let initial: String
    let ringState: RingState
    var size: CGFloat = 50

    var body: some View {
        Circle()
            .strokeBorder(ringColor, lineWidth: ringState == .none ? 0 : 2.5)
            .background {
                Circle()
                    .fill(.tint.opacity(0.2))
                    .padding(ringState == .none ? 0 : 3)
            }
            .overlay {
                Text(initial)
                    .font(.headline)
                    .foregroundStyle(.tint)
            }
            .frame(width: size, height: size)
    }

    private var ringColor: Color {
        switch ringState {
        case .none: return .clear
        case .unviewed: return .accentColor
        case .viewed: return Color(.systemGray3)
        }
    }
}
