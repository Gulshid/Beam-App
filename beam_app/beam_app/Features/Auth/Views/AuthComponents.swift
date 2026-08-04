import SwiftUI

// MARK: - Shared field identity

/// Every focusable field across Login/SignUp, so both screens can share one
/// FocusState-driven "tap next → jump to next field" flow.
enum AuthField: Hashable {
    case displayName, email, password, confirmPassword
}

// MARK: - Brand color

extension Color {
    /// Beam's primary brand blue, matching the splash screen's core mark.
    static let beamAccent = Color(red: 0.15, green: 0.48, blue: 1.0)
    static let beamAccentSecondary = Color.indigo
}

// MARK: - Background

/// The same navy/blue/purple "beam sweep" atmosphere as SplashScreenView,
/// reused behind Login and SignUp so the whole auth flow feels like one
/// continuous, branded moment rather than a splash followed by plain forms.
struct BeamAuthBackground: View {
    @State private var orbsAppeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.20),
                    Color(red: 0.10, green: 0.13, blue: 0.30),
                    Color(red: 0.05, green: 0.07, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                let size = proxy.size

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.45), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.5
                        )
                    )
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .blur(radius: 60)
                    .offset(
                        x: orbsAppeared ? -size.width * 0.28 : -size.width * 0.36,
                        y: orbsAppeared ? -size.height * 0.32 : -size.height * 0.24
                    )
                    .opacity(orbsAppeared ? 0.85 : 0)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.width * 0.45
                        )
                    )
                    .frame(width: size.width * 0.8, height: size.width * 0.8)
                    .blur(radius: 60)
                    .offset(
                        x: orbsAppeared ? size.width * 0.30 : size.width * 0.38,
                        y: orbsAppeared ? size.height * 0.62 : size.height * 0.54
                    )
                    .opacity(orbsAppeared ? 0.75 : 0)
            }
            .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: orbsAppeared)
        }
        .ignoresSafeArea()
        .onAppear { orbsAppeared = true }
    }
}

// MARK: - Logo mark

/// A compact version of the splash screen's core mark, for use as a header
/// on the auth forms themselves.
struct BeamLogoMark: View {
    var diameter: CGFloat = 72
    var symbolSize: CGFloat = 26

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.blue, Color.indigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: .blue.opacity(0.45), radius: 18, y: 8)
            .overlay(
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - Text field

/// A dark, glassy text field styled to match the auth screens, with an
/// icon, animated focus ring, optional password reveal toggle, and an
/// optional inline validation message.
struct BeamTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .never
    var autocorrectionDisabled: Bool = true
    var submitLabel: SubmitLabel = .next

    var field: AuthField
    var focusedField: FocusState<AuthField?>.Binding

    var errorText: String?
    var onSubmit: () -> Void = {}

    @State private var isRevealed = false

    private var isFocused: Bool { focusedField.wrappedValue == field }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isFocused ? Color.beamAccent : .white.opacity(0.4))
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)

                Group {
                    if isSecure && !isRevealed {
                        SecureField("", text: $text, prompt: placeholderText)
                    } else {
                        TextField("", text: $text, prompt: placeholderText)
                    }
                }
                .foregroundStyle(.white)
                .tint(Color.beamAccent)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .focused(focusedField, equals: field)
                .onSubmit(onSubmit)

                if isSecure {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isRevealed.toggle() }
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 1.5 : 1)
            )

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorText)
    }

    private var placeholderText: Text {
        Text(placeholder).foregroundStyle(.white.opacity(0.35))
    }

    private var borderColor: Color {
        if errorText != nil { return Color.red.opacity(0.6) }
        return isFocused ? Color.beamAccent.opacity(0.9) : Color.white.opacity(0.12)
    }
}

// MARK: - Primary button

/// The single filled call-to-action button used by both Sign In and Create
/// Account, with a built-in loading spinner and disabled state.
struct BeamPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.beamAccent, Color.beamAccentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .foregroundStyle(.white)
        .opacity(isDisabled ? 0.5 : 1)
        .shadow(color: Color.beamAccent.opacity(isDisabled ? 0 : 0.35), radius: 16, y: 8)
        .disabled(isDisabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

// MARK: - Error banner

/// A styled, dismiss-on-its-own error banner, swapped in for the old plain
/// red caption so failed sign-ins feel less like a crash and more like
/// gentle, expected feedback.
struct BeamErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red.opacity(0.9))
                .padding(.top, 1)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Success banner

/// Same shape as the error banner, in the brand accent color, for
/// affirmative feedback like "password reset email sent".
struct BeamSuccessBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.beamAccent)
                .padding(.top, 1)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.beamAccent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.beamAccent.opacity(0.3), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Password strength

/// Lightweight, purely client-side heuristic — just enough to nudge people
/// toward a stronger password during sign up. Not used for validation.
enum PasswordStrength: Int, Comparable {
    case tooShort = 0, weak, fair, strong

    static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(password: String) {
        guard password.count >= 6 else {
            self = .tooShort
            return
        }

        var score = 0
        if password.count >= 10 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0, 1: self = .weak
        case 2: self = .fair
        default: self = .strong
        }
    }

    var label: String {
        switch self {
        case .tooShort: return "At least 6 characters"
        case .weak: return "Weak password"
        case .fair: return "Fair password"
        case .strong: return "Strong password"
        }
    }

    var color: Color {
        switch self {
        case .tooShort: return .white.opacity(0.25)
        case .weak: return .red
        case .fair: return .orange
        case .strong: return .green
        }
    }

    /// How many of the 4 strength segments should be filled in.
    var filledSegments: Int {
        switch self {
        case .tooShort: return 1
        case .weak: return 1
        case .fair: return 2
        case .strong: return 4
        }
    }
}

struct PasswordStrengthMeter: View {
    let password: String

    private var strength: PasswordStrength { PasswordStrength(password: password) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < strength.filledSegments ? strength.color : Color.white.opacity(0.12))
                        .frame(height: 3)
                }
            }
            Text(strength.label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .animation(.easeInOut(duration: 0.2), value: password)
    }
}
