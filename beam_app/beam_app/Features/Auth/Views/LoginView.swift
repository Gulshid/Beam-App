import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showingSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Welcome back")
                        .font(.title2.bold())
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await viewModel.signIn() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)

                Button("Don't have an account? Sign up") {
                    showingSignUp = true
                }
                .font(.footnote)

                Spacer()
                Spacer()
            }
            .padding(24)
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }
}

#Preview {
    LoginView()
}
