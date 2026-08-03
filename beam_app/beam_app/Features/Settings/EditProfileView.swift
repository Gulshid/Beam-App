import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditProfileViewModel

    @State private var photoSelection: PhotosPickerItem?
    @State private var previewImage: Image?

    init(user: AppUser) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoSelection, matching: .images) {
                            avatar
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white, Color.accentColor)
                                        .background(Circle().fill(.white).padding(3))
                                }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Display name", text: $viewModel.displayName)
                        .textInputAutocapitalization(.words)
                }

                if viewModel.isSaving, viewModel.pickedImageData != nil {
                    Section {
                        ProgressView(value: viewModel.uploadProgress) {
                            Text("Uploading photo…")
                                .font(.footnote)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save() {
                                await appState.refreshCurrentUser()
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .onChange(of: photoSelection) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        viewModel.pickedImageData = data
                        if let uiImage = UIImage(data: data) {
                            previewImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        Circle()
            .fill(.tint.opacity(0.2))
            .frame(width: 96, height: 96)
            .overlay {
                if let previewImage {
                    previewImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else if let urlString = viewModel.existingPhotoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            initialLabel
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    initialLabel
                }
            }
    }

    private var initialLabel: some View {
        Text(viewModel.displayName.prefix(1).uppercased())
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(.tint)
    }
}

#Preview {
    EditProfileView(user: AppUser(id: "1", displayName: "Ada Lovelace", email: "ada@example.com"))
        .environmentObject(AppState())
}
