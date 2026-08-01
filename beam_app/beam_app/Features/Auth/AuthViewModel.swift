import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signUp() async {
        errorMessage = nil

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
