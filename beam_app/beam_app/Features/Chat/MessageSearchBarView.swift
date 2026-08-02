import SwiftUI

/// Docked above the composer when the user taps the search icon in `ChatView`'s
/// toolbar. Client-side search over already-loaded messages — see
/// `ChatViewModel.runSearch`.
struct MessageSearchBarView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search in conversation", text: $viewModel.searchQuery)
                    .focused($isFocused)
                    .submitLabel(.search)
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            if !viewModel.searchQuery.isEmpty {
                Text(matchCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40)

                Button {
                    viewModel.goToPreviousMatch()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(viewModel.searchMatchIds.isEmpty)

                Button {
                    viewModel.goToNextMatch()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(viewModel.searchMatchIds.isEmpty)
            }

            Button("Cancel") {
                viewModel.clearSearch()
                onClose()
            }
            .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onAppear { isFocused = true }
    }

    private var matchCountLabel: String {
        guard !viewModel.searchMatchIds.isEmpty else { return "0 results" }
        return "\(viewModel.currentSearchMatchIndex + 1)/\(viewModel.searchMatchIds.count)"
    }
}
