import SwiftUI
import UIKit

struct StatusImageComposerView: View {
    let imageData: Data
    let onPost: (Data, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                HStack(spacing: 12) {
                    TextField("Add a caption", text: $caption)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.35), in: Capsule())

                    Button {
                        isSubmitting = true
                        Task {
                            await onPost(imageData, caption)
                            dismiss()
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor, in: Circle())
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor, in: Circle())
                        }
                    }
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}
