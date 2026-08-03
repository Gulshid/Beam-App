import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    @State private var showingEditProfile = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingClearCacheConfirmation = false

    @AppStorage(SettingsKeys.appearance) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(SettingsKeys.chatWallpaperHex) private var chatWallpaperHex = ""
    @AppStorage(SettingsKeys.messageFontScale) private var messageFontScale: Double = 1.0
    @AppStorage(SettingsKeys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(SettingsKeys.lastSeenEnabled) private var lastSeenEnabled = true
    @AppStorage(SettingsKeys.readReceiptsEnabled) private var readReceiptsEnabled = true
    @AppStorage(SettingsKeys.mediaAutoDownloadEnabled) private var mediaAutoDownloadEnabled = true

    var body: some View {
        NavigationStack {
            List {
                profileSection
                appearanceSection
                chatsSection
                notificationsSection
                privacySection
                dataSection
                aboutSection
                accountActionsSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditProfile) {
                if let user = appState.currentUser {
                    EditProfileView(user: user)
                }
            }
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
            .alert("Clear local cache?", isPresented: $showingClearCacheConfirmation) {
                Button("Clear Cache", role: .destructive) {
                    Task { await viewModel.clearLocalCache() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This only removes data cached on this device. Nothing is deleted from the server — chats will reload the next time you open them.")
            }
            .alert("Delete your account?", isPresented: $showingDeleteConfirmation) {
                Button("Delete Account", role: .destructive) {
                    Task { _ = await viewModel.deleteAccount(appState: appState) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your Beam account and profile. This can't be undone.")
            }
            .alert("Couldn't complete that", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            Button {
                showingEditProfile = true
            } label: {
                HStack(spacing: 14) {
                    avatarView
                        .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.currentUser?.displayName ?? "Unknown")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let email = appState.currentUser?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("Edit profile")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        Circle()
            .fill(.tint.opacity(0.2))
            .overlay {
                if let urlString = appState.currentUser?.photoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Text((appState.currentUser?.displayName ?? "?").prefix(1).uppercased())
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    .clipShape(Circle())
                } else {
                    Text((appState.currentUser?.displayName ?? "?").prefix(1).uppercased())
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceRaw) {
                ForEach(AppAppearance.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option.rawValue)
                }
            }
        }
    }

    // MARK: - Chats

    private var chatsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Chat Wallpaper")
                HStack(spacing: 10) {
                    wallpaperSwatch(hex: nil)
                    ForEach(WallpaperPalette.hexColors, id: \.self) { hex in
                        wallpaperSwatch(hex: hex)
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Message Text Size")
                    Spacer()
                    Text(fontScaleLabel)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $messageFontScale, in: 0.85...1.3, step: 0.05)
            }

            Toggle("Auto-Download Media", isOn: $mediaAutoDownloadEnabled)
        } header: {
            Text("Chats")
        } footer: {
            Text("Wallpaper and text size apply across all your conversations.")
        }
    }

    private var fontScaleLabel: String {
        switch messageFontScale {
        case ..<0.95: return "Small"
        case 0.95..<1.1: return "Default"
        case 1.1..<1.2: return "Large"
        default: return "Extra Large"
        }
    }

    private func wallpaperSwatch(hex: String?) -> some View {
        Button {
            chatWallpaperHex = hex ?? ""
        } label: {
            Circle()
                .fill(hex.map { Color(hex: $0) } ?? Color(.systemGray5))
                .frame(width: 30, height: 30)
                .overlay {
                    if (hex ?? "") == chatWallpaperHex {
                        Circle().strokeBorder(Color.primary, lineWidth: 2)
                    }
                }
                .overlay {
                    if hex == nil {
                        Image(systemName: "slash.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Message Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, newValue in
                    guard newValue else { return }
                    Task {
                        let granted = await viewModel.requestNotificationPermission()
                        if !granted { notificationsEnabled = false }
                    }
                }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section {
            Toggle("Last Seen & Online", isOn: $lastSeenEnabled)
            Toggle("Read Receipts", isOn: $readReceiptsEnabled)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Turning off Last Seen or Read Receipts also hides other people's from you.")
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data & Storage") {
            Button {
                showingClearCacheConfirmation = true
            } label: {
                HStack {
                    Text("Clear Local Cache")
                    Spacer()
                    if viewModel.isClearingCache {
                        ProgressView()
                    } else if viewModel.didClearCache {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersionString)
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Account actions

    private var accountActionsSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutConfirmation = true
            } label: {
                Text("Sign Out")
            }

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                if viewModel.isDeletingAccount {
                    ProgressView()
                } else {
                    Text("Delete Account")
                }
            }
            .disabled(viewModel.isDeletingAccount)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
