import Foundation

/// App-level user profile, distinct from FirebaseAuth.User so nothing
/// outside Data/Firebase needs to import FirebaseAuth.
struct AppUser: Identifiable, Codable, Equatable {
    let id: String              // matches Firebase Auth uid
    var displayName: String
    var email: String?
    var photoURL: String?
    var lastSeen: Date?
    var fcmToken: String?

    init(id: String, displayName: String, email: String? = nil, photoURL: String? = nil, lastSeen: Date? = nil, fcmToken: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.lastSeen = lastSeen
        self.fcmToken = fcmToken
    }
}
