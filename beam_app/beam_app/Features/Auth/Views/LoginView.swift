import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var hasAttemptedSignIn = false
    @State private var contentAppeared = false

    @FocusState private var focusedField: AuthField?

    private var emailError: String? {
        guard hasAttemptedSignIn, !viewModel.email.isEmpty else { return nil }
        return isValidEmail(viewModel.email) ? nil : "Enter a valid email address."
    }

    private var passwordError: String? {
        guard hasAttemptedSignIn else { return nil }
        return viewModel.password.isEmpty ? "Enter your password." : nil
    }

    private var canSubmit: Bool {
        !viewModel.email.isEmpty && !viewModel.password.isEmpty && !viewModel.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeamAuthBackground()

                ScrollView {
                    VStack(spacing: 28) {
                        header
                        form
                        footer
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 48)
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
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordSheet(viewModel: viewModel)
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 14) {
            BeamLogoMark()

            VStack(spacing: 6) {
                Text("Welcome back")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Sign in to keep the conversation going.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            BeamTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                textContentType: .username,
                submitLabel: .next,
                field: .email,
                focusedField: $focusedField,
                errorText: emailError,
                onSubmit: { focusedField = .password }
            )

            VStack(alignment: .trailing, spacing: 8) {
                BeamTextField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $viewModel.password,
                    isSecure: true,
                    textContentType: .password,
                    submitLabel: .go,
                    field: .password,
                    focusedField: $focusedField,
                    errorText: passwordError,
                    onSubmit: attemptSignIn
                )

                Button("Forgot password?") {
                    showingForgotPassword = true
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.beamAccent)
            }

            if let errorMessage = viewModel.errorMessage {
                BeamErrorBanner(message: errorMessage)
            }

            BeamPrimaryButton(
                title: "Sign In",
                isLoading: viewModel.isLoading,
                isDisabled: !canSubmit,
                action: attemptSignIn
            )
            .padding(.top, 4)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(.white.opacity(0.55))
            Button("Sign up") {
                showingSignUp = true
            }
            .foregroundStyle(Color.beamAccent)
            .fontWeight(.semibold)
        }
        .font(.footnote)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func attemptSignIn() {
        hasAttemptedSignIn = true
        guard canSubmit, isValidEmail(viewModel.email) else { return }
        Task { await viewModel.signIn() }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Forgot password sheet

private struct ForgotPasswordSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedFieldProxy: AuthField?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BeamAuthBackground()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(16)

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.beamAccent)
                        .padding(.bottom, 4)

                    Text("Reset your password")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("We'll email a reset link to the address below.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                BeamTextField(
                    icon: "envelope.fill",
                    placeholder: "Email",
                    text: $viewModel.email,
                    keyboardType: .emailAddress,
                    textContentType: .username,
                    submitLabel: .send,
                    field: .email,
                    focusedField: $focusedFieldProxy,
                    onSubmit: sendReset
                )

                if let errorMessage = viewModel.errorMessage {
                    BeamErrorBanner(message: errorMessage)
                }
                if let infoMessage = viewModel.infoMessage {
                    BeamSuccessBanner(message: infoMessage)
                }

                BeamPrimaryButton(
                    title: "Send Reset Link",
                    isLoading: viewModel.isLoading,
                    isDisabled: viewModel.email.isEmpty,
                    action: sendReset
                )

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .presentationBackground(.clear)
        .onAppear {
            viewModel.errorMessage = nil
            viewModel.infoMessage = nil
        }
        .onDisappear {
            viewModel.errorMessage = nil
            viewModel.infoMessage = nil
        }
    }

    private func sendReset() {
        Task { await viewModel.sendPasswordReset() }
    }
}

#Preview {
    LoginView()
}
