import Foundation

final class CloudinaryMediaRepository: MediaRepository {
    func upload(data: Data, kind: MediaKind, progress: @escaping (Double) -> Void) async throws -> MediaUploadResult {
        let (filename, mimeType, resourceType) = fileMetadata(for: kind)
        let uploader = CloudinaryUploader(
            cloudName: CloudinaryConfig.cloudName,
            uploadPreset: CloudinaryConfig.uploadPreset,
            progress: progress
        )
        let response = try await uploader.upload(
            data: data,
            filename: filename,
            mimeType: mimeType,
            resourceType: resourceType,
            folder: CloudinaryConfig.mediaFolder
        )
        return MediaUploadResult(url: response.secureUrl, duration: response.duration)
    }

    private func fileMetadata(for kind: MediaKind) -> (filename: String, mimeType: String, resourceType: String) {
        switch kind {
        case .image:
            return ("\(UUID().uuidString).jpg", "image/jpeg", "image")
        case .video:
            return ("\(UUID().uuidString).mp4", "video/mp4", "video")
        case .audio:
            // Cloudinary groups audio under the "video" resource type — there is no
            // separate audio upload endpoint.
            return ("\(UUID().uuidString).m4a", "audio/m4a", "video")
        }
    }
}
