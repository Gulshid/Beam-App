import SwiftUI

/// The Status tab: "My status" (add/view your own) plus a "Recent updates" list of
/// contacts' status reels. "Contacts" here means anyone you already have a
/// conversation with — see `StatusViewModel`.
struct StatusView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = StatusViewModel()

    @State private var showingComposerChoice = false
    @State private var showingTextComposer = false
    @State private var showingImagePicker = false
    @State private var pickedImageData: Data?
    @State private var viewerContext: StatusViewerContext?

    private var currentUserId: String { appState.currentUser?.id ?? "" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    myStatusRow
                }

                if !viewModel.contactGroups.isEmpty {
                    Section("Recent updates") {
                        ForEach(viewModel.contactGroups) { group in
                            Button {
                                viewerContext = StatusViewerContext(
                                    groups: viewModel.contactGroups,
                                    startAt: group.userId,
                                    isOwn: false
                                )
                            } label: {
                                StatusRowView(
                                    name: viewModel.displayName(for: group.userId),
                                    latestAt: group.latest?.createdAt ?? Date(),
                                    isUnviewed: group.hasUnviewed(for: currentUserId)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "No recent updates",
                            systemImage: "circle.dashed",
                            description: Text("Status updates from your contacts will show up here.")
                        )
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Status")
            .confirmationDialog("Add status update", isPresented: $showingComposerChoice, titleVisibility: .visible) {
                Button("Type a Status") { showingTextComposer = true }
                Button("Photo") { showingImagePicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .mediaPicker(isPresented: $showingImagePicker) { data, kind in
                guard kind == .image else { return }
                pickedImageData = data
            }
            .sheet(isPresented: $showingTextComposer) {
                StatusTextComposerView { text, colorHex in
                    _ = await viewModel.postText(text, backgroundColorHex: colorHex)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { pickedImageData != nil },
                    set: { if !$0 { pickedImageData = nil } }
                )
            ) {
                if let pickedImageData {
                    StatusImageComposerView(imageData: pickedImageData) { data, caption in
                        _ = await viewModel.postImage(data: data, caption: caption)
                    }
                }
            }
            .fullScreenCover(item: $viewerContext) { context in
                StatusViewerView(context: context, viewModel: viewModel)
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.postErrorMessage != nil },
                    set: { if !$0 { viewModel.postErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.postErrorMessage ?? "")
            }
        }
        .task {
            if !currentUserId.isEmpty {
                viewModel.start(currentUserId: currentUserId)
            }
        }
        .onDisappear { viewModel.stop() }
    }

    private var myStatusRow: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                StatusAvatarRing(
                    initial: (appState.currentUser?.displayName ?? "?").prefix(1).uppercased(),
                    ringState: viewModel.myStatuses.isEmpty ? .none : .viewed
                )

                Button {
                    showingComposerChoice = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color.accentColor)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("My status")
                    .font(.body.weight(.semibold))
                if let latest = viewModel.myStatuses.last {
                    Text(latest.createdAt, style: .relative)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap to add a status update")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.myStatuses.isEmpty {
                showingComposerChoice = true
            } else {
                viewerContext = StatusViewerContext(
                    groups: [StatusGroup(userId: currentUserId, statuses: viewModel.myStatuses)],
                    startAt: currentUserId,
                    isOwn: true
                )
            }
        }
    }
}

#Preview {
    StatusView()
        .environmentObject(AppState())
}
