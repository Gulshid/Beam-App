import SwiftUI

struct StatusRowView: View {
    let name: String
    let latestAt: Date
    let isUnviewed: Bool
    var photoURL: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            StatusAvatarRing(
                initial: name.prefix(1).uppercased(),
                ringState: isUnviewed ? .unviewed : .viewed,
                photoURL: photoURL
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(latestAt, style: .relative)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
