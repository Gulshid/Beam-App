import SwiftUI

/// One person's status "reel" inside the full-screen viewer: progress bars across
/// the top (one per status), auto-advance timer, and tap-left/tap-right navigation.
/// Hold-to-pause is intentionally omitted — a `DragGesture`/`LongPressGesture` on
/// this same surface would fight with `StatusViewerView`'s page-swipe-between-people
/// gesture; a future pass could add it via a dedicated `UIViewRepresentable`
/// recognizer with an explicit `require(toFail:)` against the page gesture.
struct StatusReelView: View {
    let group: StatusGroup
    let isOwn: Bool
    let displayName: String
    let onViewed: (Status) -> Void
    let onDelete: (Status) -> Void
    let viewerNames: (Status) -> [String]
    let onReact: (Status, String) -> Void
    let myReaction: (Status) -> String?
    let reactionRows: (Status) -> [(name: String, emoji: String)]
    let goToPreviousPerson: () -> Void
    let goToNextPerson: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var progress: Double = 0
    @State private var showingViewers = false
    @State private var showingDeleteConfirm = false
    @State private var reactionBounce: String?

    private static let imageDuration: Double = 5
    private static let textDuration: Double = 4
    private static let tick: Double = 0.03

    private var statuses: [Status] { group.statuses }
    private var currentStatus: Status? { statuses.indices.contains(index) ? statuses[index] : nil }
    private var duration: Double {
        currentStatus?.type == .image ? Self.imageDuration : Self.textDuration
    }
    private var isPausedBySheet: Bool { showingViewers || showingDeleteConfirm }

    var body: some View {
        ZStack {
            background

            // `tapZones` MUST come before the chrome below it, not after. SwiftUI
            // gives later ZStack children hit-testing priority over earlier ones,
            // so with tapZones last (as it used to be) its two full-screen
            // invisible tap-to-advance/back rectangles sat on top of literally
            // everything — including the trash icon, the close (X) button, the
            // views pill, and the reaction bar — and ate every tap meant for them.
            // That's why delete and the views/reactions buttons looked broken:
            // tapping them just advanced or rewound the story instead. Putting it
            // here means the real buttons below (drawn after, so on top) get first
            // claim on their own bounds, and only genuinely empty screen area
            // still falls through to advance/back.
            tapZones

            VStack(spacing: 10) {
                progressBars
                header
                Spacer()
                captionOrText
                Spacer()
                if isOwn {
                    ownFooter
                } else {
                    reactionBar
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .onReceive(Timer.publish(every: Self.tick, on: .main, in: .common).autoconnect()) { _ in
            guard !isPausedBySheet else { return }
            progress += Self.tick / duration
            if progress >= 1 {
                advance(forward: true)
            }
        }
        .onChange(of: index) { _, _ in
            progress = 0
            markViewedIfNeeded()
        }
        .onAppear { markViewedIfNeeded() }
        .confirmationDialog("Delete this status?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let currentStatus { onDelete(currentStatus) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingViewers) {
            viewersSheet
        }
    }

    // MARK: - Background

    @ViewBuilder private var background: some View {
        if currentStatus?.type == .text {
            Color(hex: currentStatus?.backgroundColorHex ?? "#0A84FF")
                .ignoresSafeArea()
        } else {
            Color.black.ignoresSafeArea()
            if let urlString = currentStatus?.mediaURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        ProgressView().tint(.white)
                    }
                }
            }
        }
    }

    // MARK: - Chrome

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(statuses.indices, id: \.self) { i in
                GeometryReader { geo in
                    Capsule()
                        .fill(.white.opacity(0.3))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.white)
                                .frame(width: geo.size.width * fraction(for: i))
                        }
                }
                .frame(height: 3)
            }
        }
    }

    private func fraction(for i: Int) -> Double {
        if i < index { return 1 }
        if i == index { return min(max(progress, 0), 1) }
        return 0
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.white.opacity(0.25))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(displayName.prefix(1).uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let currentStatus {
                    Text(currentStatus.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            if isOwn {
                Button {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder private var captionOrText: some View {
        if let currentStatus {
            if currentStatus.type == .text {
                Text(currentStatus.text ?? "")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            } else if let caption = currentStatus.text, !caption.isEmpty {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
            }
        }
    }

    /// Shown only to the poster: the views pill (unchanged) plus, when anyone has
    /// reacted, a second pill summarizing the distinct emojis used. Tapping either
    /// opens the same sheet, just scrolled to the relevant section.
    private var ownFooter: some View {
        HStack(spacing: 8) {
            Button {
                showingViewers = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                    Text("\(currentStatus?.viewedBy?.count ?? 0) views")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.35), in: Capsule())
            }

            if let currentStatus, let rows = reactionRowsIfAny(currentStatus) {
                Button {
                    showingViewers = true
                } label: {
                    HStack(spacing: 4) {
                        Text(distinctEmojis(rows))
                        Text("\(rows.count)")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.35), in: Capsule())
                }
            }
        }
    }

    private func reactionRowsIfAny(_ status: Status) -> [(name: String, emoji: String)]? {
        let rows = reactionRows(status)
        return rows.isEmpty ? nil : rows
    }

    private func distinctEmojis(_ rows: [(name: String, emoji: String)]) -> String {
        var seen = Set<String>()
        var ordered: [String] = []
        for row in rows where !seen.contains(row.emoji) {
            seen.insert(row.emoji)
            ordered.append(row.emoji)
        }
        return ordered.joined()
    }

    /// Shown when viewing someone else's status: tap an emoji to react. Tapping
    /// your current reaction again just re-sends the same emoji (harmless — it
    /// overwrites your one entry with the same value), it doesn't toggle it off,
    /// mirroring how a single tap-to-react works in most chat apps.
    private var reactionBar: some View {
        HStack(spacing: 10) {
            ForEach(Status.quickReactions, id: \.self) { emoji in
                let isSelected = currentStatus.flatMap(myReaction) == emoji
                Button {
                    guard let currentStatus else { return }
                    onReact(currentStatus, emoji)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        reactionBounce = emoji
                    }
                } label: {
                    Text(emoji)
                        .font(.system(size: isSelected ? 26 : 22))
                        .scaleEffect(reactionBounce == emoji ? 1.3 : 1.0)
                        .padding(8)
                        .background(
                            Circle().fill(isSelected ? .white.opacity(0.25) : .clear)
                        )
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSelected)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.35), in: Capsule())
    }

    private var viewersSheet: some View {
        NavigationStack {
            List {
                Section("Viewed by") {
                    if let currentStatus, let names = currentStatus.viewedBy, !names.isEmpty {
                        ForEach(viewerNames(currentStatus), id: \.self) { name in
                            Text(name)
                        }
                    } else {
                        Text("No views yet")
                            .foregroundStyle(.secondary)
                    }
                }

                if let currentStatus, !reactionRows(currentStatus).isEmpty {
                    Section("Reactions") {
                        ForEach(Array(reactionRows(currentStatus).enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(row.emoji)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Status activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingViewers = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Navigation

    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { advance(forward: false) }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { advance(forward: true) }
        }
    }

    private func advance(forward: Bool) {
        if forward {
            if index < statuses.count - 1 {
                index += 1
            } else {
                goToNextPerson()
            }
        } else {
            if index > 0 {
                index -= 1
            } else {
                goToPreviousPerson()
            }
        }
    }

    private func markViewedIfNeeded() {
        guard let currentStatus, !isOwn else { return }
        onViewed(currentStatus)
    }
}
