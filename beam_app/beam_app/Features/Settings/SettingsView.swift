import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(.tint.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Text((appState.currentUser?.displayName ?? "?").prefix(1).uppercased())
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.currentUser?.displayName ?? "Unknown")
                                .font(.headline)
                            if let email = appState.currentUser?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Sign out of Beam?",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
