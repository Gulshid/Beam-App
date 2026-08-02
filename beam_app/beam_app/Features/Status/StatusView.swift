import SwiftUI

/// The Status tab. Status updates (photo/text stories that expire after 24h) aren't
/// backed by any data model yet — this is the tab's placeholder shell so the tab bar
/// is complete; wiring it up to Firestore is future work, same shape as how Groups
/// piggybacks on `Conversation` today.
struct StatusView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(.tint.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Text((appState.currentUser?.displayName ?? "?").prefix(1).uppercased())
                                        .font(.headline)
                                        .foregroundStyle(.tint)
                                }
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, Color.accentColor)
                                .background(Circle().fill(.white))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("My status")
                                .font(.body.weight(.semibold))
                            Text("Tap to add a status update")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ContentUnavailableView(
                        "No recent updates",
                        systemImage: "circle.dashed",
                        description: Text("Status updates from your contacts will show up here.")
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Status")
        }
    }
}

#Preview {
    StatusView()
        .environmentObject(AppState())
}
