import Foundation

enum MediaKind {
    case image
    case video
    case audio
}

struct MediaUploadResult {
    let url: String
    /// Server-reported duration for audio/video, when available. Callers that already
    /// know the duration (e.g. the voice recorder timed itself) can prefer their own value.
    let duration: Double?
}

protocol MediaRepository {
    /// Uploads raw local media data and returns its hosted URL.
    /// - Parameter progress: called on the main actor with a 0...1 fraction as the upload proceeds.
    func upload(data: Data, kind: MediaKind, progress: @escaping (Double) -> Void) async throws -> MediaUploadResult
}
