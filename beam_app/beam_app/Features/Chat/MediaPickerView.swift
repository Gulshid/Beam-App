import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Presents the system photo/video library picker via a boolean binding, converts the
/// selection into raw Data + MediaKind, and hands it back through `onPicked`.
/// Runs out-of-process (it's the system picker), so no photo-library Info.plist entry is needed.
struct MediaPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onPicked: (Data, MediaKind) -> Void

    @State private var selection: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $selection, matching: .any(of: [.images, .videos]))
            .onChange(of: selection) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let isVideo = newItem.supportedContentTypes.contains { $0.conforms(to: .movie) }
                        onPicked(data, isVideo ? .video : .image)
                    }
                    selection = nil
                }
            }
    }
}

extension View {
    func mediaPicker(isPresented: Binding<Bool>, onPicked: @escaping (Data, MediaKind) -> Void) -> some View {
        modifier(MediaPickerModifier(isPresented: isPresented, onPicked: onPicked))
    }
}
