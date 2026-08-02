import Foundation

enum CloudinaryConfig {
    /// TODO: Cloudinary Dashboard (cloudinary.com/console) → shown top-left, e.g. "dz1a2b3c4".
    static let cloudName = "YOUR_CLOUD_NAME"

    /// TODO: Dashboard → Settings (gear icon) → Upload → "Upload presets" → Add upload preset.
    /// Set Signing Mode = **Unsigned**. Per the architecture doc §2, also lock it down there:
    /// restrict the folder, allowed formats (jpg/png/mp4/m4a), and max file size, since an
    /// unsigned preset name is effectively public once it's compiled into the app.
    static let uploadPreset = "YOUR_UNSIGNED_UPLOAD_PRESET"

    /// Folder every message upload lands in, matching the preset's folder restriction above.
    static let mediaFolder = "beam_app/messages"
}
