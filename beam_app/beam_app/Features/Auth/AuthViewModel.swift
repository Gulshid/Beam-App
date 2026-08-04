import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var isLoading = false

    private let userRepository: UserRepository

    init(userRepository: UserRepository = FirestoreUserRepository()) {
        self.userRepository = userRepository
    }

    func signIn() async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    /// Sends a Firebase password-reset email for the current `email` field.
    /// Sets `infoMessage` on success so the UI can show gentle confirmation
    /// rather than silently doing nothing.
    func sendPasswordReset() async {
        errorMessage = nil
        infoMessage = nil

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email above first, then tap \"Forgot password?\"."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmed)
            infoMessage = "Password reset email sent to \(trimmed)."
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signUp() async {
        errorMessage = nil
        infoMessage = nil

        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a display name."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            // AppState's auth-state listener may have already created the Firestore
            // user doc with a fallback name (it can fire before commitChanges above
            // finishes). Explicitly overwrite it now that we know the real name.
            try? await userRepository.updateDisplayName(uid: result.user.uid, displayName: displayName)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .invalidEmail: return "That email address doesn't look right."
        case .emailAlreadyInUse: return "An account already exists with that email."
        case .weakPassword: return "Password should be at least 6 characters."
        case .wrongPassword, .userNotFound: return "Incorrect email or password."
        case .networkError: return "Network error — check your connection."
        default: return error.localizedDescription
        }
    }
}
