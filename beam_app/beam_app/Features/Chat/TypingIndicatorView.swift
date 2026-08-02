import SwiftUI

/// Shows a bouncing-dots bubble (mirrors an incoming `MessageBubbleView`) plus a
/// "X is typing…" caption. Pass the display names of whoever's currently typing —
/// an empty array means nobody is, and callers should just not show this view.
struct TypingIndicatorView: View {
    let names: [String]

    @State private var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            HStack {
                dots
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

                Spacer(minLength: 40)
            }
        }
        .onAppear { animate = true }
        .onDisappear { animate = false }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var dots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundStyle(.secondary)
                    .offset(y: animate ? -3 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animate
                    )
            }
        }
    }

    private var label: String? {
        switch names.count {
        case 0: return nil
        case 1: return "\(names[0]) is typing…"
        case 2: return "\(names[0]) and \(names[1]) are typing…"
        default: return "Several people are typing…"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TypingIndicatorView(names: ["Alex"])
        TypingIndicatorView(names: ["Alex", "Jordan"])
        TypingIndicatorView(names: ["Alex", "Jordan", "Sam"])
    }
    .padding()
}
