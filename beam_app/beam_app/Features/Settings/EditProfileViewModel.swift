import Foundation
import SwiftUI

@MainActor
final class EditProfileViewModel: ObservableObject {
    @Published var displayName: String
    @Published var pickedImageData: Data?
    @Published var isSaving = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?

    private let uid: String
    let existingPhotoURL: String?
    private let userRepository: UserRepository
    private let mediaRepository: MediaRepository

    init(
        user: AppUser,
        userRepository: UserRepository = FirestoreUserRepository(),
        mediaRepository: MediaRepository = CloudinaryMediaRepository()
    ) {
        self.uid = user.id
        self.displayName = user.displayName
        self.existingPhotoURL = user.photoURL
        self.userRepository = userRepository
        self.mediaRepository = mediaRepository
    }

    var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedName.isEmpty && !isSaving
    }

    /// Saves the display name (always) and, if the user picked a new photo, uploads
    /// it to Cloudinary first and writes the resulting URL. Returns `true` on success
    /// so the view can dismiss.
    func save() async -> Bool {
        guard canSave else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            if let pickedImageData {
                let result = try await mediaRepository.upload(data: pickedImageData, kind: .image) { [weak self] progress in
                    self?.uploadProgress = progress
                }
                try await userRepository.updatePhotoURL(uid: uid, photoURL: result.url)
            }
            try await userRepository.updateDisplayName(uid: uid, displayName: trimmedName)
            return true
        } catch {
            errorMessage = "Couldn't save your profile. \(error.localizedDescription)"
            return false
        }
    }
}
