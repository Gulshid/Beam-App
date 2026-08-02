import SwiftUI

struct AddMembersView: View {
    @StateObject private var picker: UserMultiSelectViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false

    let onAdd: ([AppUser]) async -> Void

    init(currentUserId: String, excludingMemberIds: Set<String>, onAdd: @escaping ([AppUser]) async -> Void) {
        self.onAdd = onAdd
        _picker = StateObject(wrappedValue: UserMultiSelectViewModel(
            currentUserId: currentUserId,
            excludedIds: excludingMemberIds
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                UserMultiSelectView(
                    viewModel: picker,
                    emptyStateTitle: "Add people",
                    emptyStateDescription: "Search for people to add to this group."
                )

                // Bottom bar rather than a toolbar .confirmationAction — while the
                // search field is focused, iOS collapses the nav bar down to just the
                // search field + its own "Cancel", hiding any trailing toolbar button.
                Divider()
                Button {
                    Task {
                        isAdding = true
                        await onAdd(picker.selectedUsers)
                        isAdding = false
                        dismiss()
                    }
                } label: {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(picker.selectedUsers.isEmpty || isAdding)
                .padding()
            }
            .navigationTitle("Add People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isAdding {
                    ProgressView()
                }
            }
        }
    }
}
