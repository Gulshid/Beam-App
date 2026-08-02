import SwiftUI

/// Navigation-path payload for pushing `GroupInfoView` from `ChatView`, alongside the
/// existing `String` (conversationId) destination used for chat threads themselves.
struct GroupInfoRoute: Hashable {
    let conversationId: String
}

struct GroupInfoView: View {
    @StateObject private var viewModel: GroupInfoViewModel
    @State private var showingAddMembers = false
    @State private var showingLeaveConfirmation = false

    /// Called once `leaveGroup()` succeeds, so the caller can pop the whole stack back
    /// to the conversation list — this screen and the chat thread behind it both stop
    /// being valid once the user is no longer a member.
    let onLeft: () -> Void

    init(conversationId: String, currentUserId: String, onLeft: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: GroupInfoViewModel(
            conversationId: conversationId,
            currentUserId: currentUserId
        ))
        self.onLeft = onLeft
    }

    var body: some View {
        Form {
            Section("Group Name") {
                TextField("Group name", text: $viewModel.editableTitle)
                    .onSubmit {
                        Task { await viewModel.saveTitleIfChanged() }
                    }
            }

            Section {
                ForEach(viewModel.members) { member in
                    HStack {
                        Circle()
                            .fill(.tint.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(member.displayName.prefix(1).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.tint)
                            }
                        Text(member.displayName)
                        if member.id == viewModel.currentUserId {
                            Spacer()
                            Text("You").foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showingAddMembers = true
                } label: {
                    Label("Add People", systemImage: "person.badge.plus")
                }
            } header: {
                Text("\(viewModel.members.count) Members")
            }

            Section {
                Button("Leave Group", role: .destructive) {
                    showingLeaveConfirmation = true
                }
            }
        }
        .navigationTitle("Group Info")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sheet(isPresented: $showingAddMembers) {
            AddMembersView(
                currentUserId: viewModel.currentUserId,
                excludingMemberIds: Set(viewModel.members.map(\.id))
            ) { selected in
                await viewModel.addMembers(selected)
            }
        }
        .confirmationDialog(
            "Leave this group?",
            isPresented: $showingLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                Task {
                    await viewModel.leaveGroup()
                    if viewModel.didLeave {
                        onLeft()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupInfoView(conversationId: "preview-id", currentUserId: "preview-uid") {}
    }
}
