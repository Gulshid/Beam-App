import SwiftUI

/// What to show when the status viewer is presented: which reels, in what order,
/// which one to open on, and whether it's the current user's own status (enables
/// delete + the viewer-count footer in `StatusReelView`).
struct StatusViewerContext: Identifiable {
    let id = UUID()
    let groups: [StatusGroup]
    let startAt: String
    let isOwn: Bool
}

struct StatusViewerView: View {
    let context: StatusViewerContext
    @ObservedObject var viewModel: StatusViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var groupIndex: Int

    init(context: StatusViewerContext, viewModel: StatusViewModel) {
        self.context = context
        self.viewModel = viewModel
        let startIndex = context.groups.firstIndex(where: { $0.userId == context.startAt }) ?? 0
        _groupIndex = State(initialValue: startIndex)
    }

    var body: some View {
        TabView(selection: $groupIndex) {
            ForEach(Array(context.groups.enumerated()), id: \.offset) { offset, group in
                StatusReelView(
                    group: group,
                    isOwn: context.isOwn,
                    displayName: context.isOwn ? "My status" : viewModel.displayName(for: group.userId),
                    onViewed: { viewModel.markViewed($0) },
                    onDelete: { status in
                        Task {
                            await viewModel.deleteMyStatus(status)
                            dismiss()
                        }
                    },
                    viewerNames: { viewModel.viewerNames(for: $0) },
                    onReact: { status, emoji in viewModel.react(to: status, emoji: emoji) },
                    myReaction: { viewModel.myReaction(to: $0) },
                    reactionRows: { viewModel.reactionRows(for: $0) },
                    goToPreviousPerson: { advance(by: -1) },
                    goToNextPerson: { advance(by: 1) }
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
    }

    private func advance(by delta: Int) {
        let next = groupIndex + delta
        guard context.groups.indices.contains(next) else {
            dismiss()
            return
        }
        groupIndex = next
    }
}
