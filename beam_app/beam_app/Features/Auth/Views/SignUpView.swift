import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var confirmPassword = ""
    @State private var hasAttemptedSignUp = false
    @State private var contentAppeared = false

    @FocusState private var focusedField: AuthField?

    private var displayNameError: String? {
        guard hasAttemptedSignUp else { return nil }
        return viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Enter a display name." : nil
    }

    private var emailError: String? {
        guard hasAttemptedSignUp, !viewModel.email.isEmpty else { return nil }
        return isValidEmail(viewModel.email) ? nil : "Enter a valid email address."
    }

    private var passwordError: String? {
        guard hasAttemptedSignUp, !viewModel.password.isEmpty else { return nil }
        return viewModel.password.count < 6 ? "Use at least 6 characters." : nil
    }

    private var confirmPasswordError: String? {
        guard hasAttemptedSignUp, !confirmPassword.isEmpty else { return nil }
        return confirmPassword == viewModel.password ? nil : "Passwords don't match."
    }

    private var canSubmit: Bool {
        !viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && !viewModel.email.isEmpty
            && viewModel.password.count >= 6
            && confirmPassword == viewModel.password
            && !viewModel.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeamAuthBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        form
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 12)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    contentAppeared = true
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            BeamLogoMark(diameter: 60, symbolSize: 22)

            Text("Join Beam and start chatting in seconds.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            BeamTextField(
                icon: "person.fill",
                placeholder: "Display name",
                text: $viewModel.displayName,
                textContentType: .name,
                autocapitalization: .words,
                autocorrectionDisabled: false,
                submitLabel: .next,
                field: .displayName,
                focusedField: $focusedField,
                errorText: displayNameError,
                onSubmit: { focusedField = .email }
            )

            BeamTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                submitLabel: .next,
                field: .email,
                focusedField: $focusedField,
                errorText: emailError,
                onSubmit: { focusedField = .password }
            )

            VStack(alignment: .leading, spacing: 8) {
                BeamTextField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $viewModel.password,
                    isSecure: true,
                    textContentType: .newPassword,
                    submitLabel: .next,
                    field: .password,
                    focusedField: $focusedField,
                    errorText: passwordError,
                    onSubmit: { focusedField = .confirmPassword }
                )

                if !viewModel.password.isEmpty {
                    PasswordStrengthMeter(password: viewModel.password)
                        .padding(.horizontal, 4)
                }
            }

            BeamTextField(
                icon: "lock.fill",
                placeholder: "Confirm password",
                text: $confirmPassword,
                isSecure: true,
                textContentType: .newPassword,
                submitLabel: .go,
                field: .confirmPassword,
                focusedField: $focusedField,
                errorText: confirmPasswordError,
                onSubmit: attemptSignUp
            )

            if let errorMessage = viewModel.errorMessage {
                BeamErrorBanner(message: errorMessage)
            }

            BeamPrimaryButton(
                title: "Create Account",
                isLoading: viewModel.isLoading,
                isDisabled: !canSubmit,
                action: attemptSignUp
            )
            .padding(.top, 4)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    // MARK: - Actions

    private func attemptSignUp() {
        hasAttemptedSignUp = true
        guard canSubmit, isValidEmail(viewModel.email) else { return }

        Task {
            await viewModel.signUp()
            if viewModel.errorMessage == nil {
                await appState.refreshCurrentUser()
                dismiss()
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

#Preview {
    SignUpView()
        .environmentObject(AppState())
}
