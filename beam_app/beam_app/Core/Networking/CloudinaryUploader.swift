import Foundation

struct CloudinaryUploadResponse: Decodable {
    let secureUrl: String
    let publicId: String
    let duration: Double?

    enum CodingKeys: String, CodingKey {
        case secureUrl = "secure_url"
        case publicId = "public_id"
        case duration
    }
}

enum CloudinaryUploadError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Cloudinary returned an unexpected response."
        case .server(let message): return message
        }
    }
}

/// Low-level multipart uploader for Cloudinary's *unsigned* upload endpoint — no server
/// component required (see architecture doc §2). One instance handles exactly one upload;
/// create a fresh instance per call so the delegate-based progress callback can't leak
/// across unrelated requests.
final class CloudinaryUploader: NSObject, URLSessionTaskDelegate {
    private let cloudName: String
    private let uploadPreset: String
    private let progressHandler: (Double) -> Void

    init(cloudName: String, uploadPreset: String, progress: @escaping (Double) -> Void = { _ in }) {
        self.cloudName = cloudName
        self.uploadPreset = uploadPreset
        self.progressHandler = progress
    }

    /// - Parameter resourceType: "image" or "video". Cloudinary has no separate audio
    ///   endpoint — voice-note (.m4a) uploads go through "video" as well.
    func upload(data: Data, filename: String, mimeType: String, resourceType: String, folder: String) async throws -> CloudinaryUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/\(resourceType)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = nil // body is sent via `upload(for:from:)` below, not here

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("upload_preset", uploadPreset)
        appendField("folder", folder)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // A dedicated session (rather than .shared) so this instance can be the
        // URLSessionTaskDelegate that receives per-chunk progress callbacks.
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (responseData, response) = try await session.upload(for: request, from: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudinaryUploadError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode([String: [String: String]].self, from: responseData))?["error"]?["message"]
            throw CloudinaryUploadError.server(message ?? "Upload failed with status \(httpResponse.statusCode).")
        }

        return try JSONDecoder().decode(CloudinaryUploadResponse.self, from: responseData)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let handler = progressHandler
        Task { @MainActor in
            handler(fraction)
        }
    }
}
