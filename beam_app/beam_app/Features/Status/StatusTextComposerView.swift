import SwiftUI

/// Full-screen text-status composer — types straight onto a colored card, tap the
/// palette button to cycle background colors, mirroring WhatsApp's text-status flow.
struct StatusTextComposerView: View {
    let onPost: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var colorIndex = 0
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    private var backgroundHex: String { StatusPalette.hexColors[colorIndex] }

    var body: some View {
        ZStack {
            Color(hex: backgroundHex).ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button {
                        colorIndex = (colorIndex + 1) % StatusPalette.hexColors.count
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .padding()

                Spacer()

                TextField("", text: $text, axis: .vertical)
                    .focused($isFocused)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .tint(.white)
                    .padding(.horizontal, 28)
                    .overlay(alignment: .top) {
                        if text.isEmpty {
                            Text("Type a status")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                                .allowsHitTesting(false)
                        }
                    }

                Spacer()

                Button {
                    let toPost = text
                    isSubmitting = true
                    Task {
                        await onPost(toPost, backgroundHex)
                        dismiss()
                    }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(Color(hex: backgroundHex))
                        }
                        Text("Post Status")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                    .foregroundStyle(Color(hex: backgroundHex))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .onAppear { isFocused = true }
    }
}

#Preview {
    StatusTextComposerView { _, _ in }
}
