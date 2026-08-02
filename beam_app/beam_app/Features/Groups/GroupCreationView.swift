import SwiftUI

struct GroupCreationView: View {
    @StateObject private var picker: UserMultiSelectViewModel
    @StateObject private var creationVM = GroupCreationViewModel()
    @State private var groupTitle = ""
    @Environment(\.dismiss) private var dismiss

    let currentUserId: String
    let onCreated: (String) -> Void

    init(currentUserId: String, onCreated: @escaping (String) -> Void) {
        self.currentUserId = currentUserId
        self.onCreated = onCreated
        _picker = StateObject(wrappedValue: UserMultiSelectViewModel(currentUserId: currentUserId))
    }

    /// A "group" with only one other person is just a direct chat with extra steps —
    /// require at least 2 others (3 people total, including the creator).
    private var canCreate: Bool {
        picker.selectedUsers.count >= 2 && !groupTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Group name", text: $groupTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                UserMultiSelectView(
                    viewModel: picker,
                    emptyStateTitle: "Add people",
                    emptyStateDescription: "Search for at least 2 people to start a group."
                )

                // Deliberately NOT the toolbar's .confirmationAction: while the search
                // field from UserMultiSelectView's .searchable is focused, iOS collapses
                // the nav bar down to just the search field + its own "Cancel", hiding
                // any trailing toolbar button entirely. A bottom bar stays reachable
                // regardless of search state.
                Divider()
                Button {
                    Task {
                        let memberIds = picker.selectedUsers.map(\.id) + [currentUserId]
                        if let conversationId = await creationVM.createGroup(
                            title: groupTitle.trimmingCharacters(in: .whitespaces),
                            memberIds: memberIds
                        ) {
                            onCreated(conversationId)
                        }
                    }
                } label: {
                    Text("Create Group")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate || creationVM.isCreating)
                .padding()
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if creationVM.isCreating {
                    ProgressView()
                }
            }
        }
    }
}

#Preview {
    GroupCreationView(currentUserId: "preview-uid") { _ in }
}
