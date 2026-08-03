import SwiftUI

/// Central place for the `@AppStorage` keys Settings writes to, so other features
/// (like `ChatView`'s wallpaper background) can read the same values without
/// hardcoding string literals in multiple places.
enum SettingsKeys {
    static let appearance = "settings.appearance"
    static let chatWallpaperHex = "settings.chatWallpaperHex"
    static let messageFontScale = "settings.messageFontScale"
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let lastSeenEnabled = "settings.lastSeenEnabled"
    static let readReceiptsEnabled = "settings.readReceiptsEnabled"
    static let mediaAutoDownloadEnabled = "settings.mediaAutoDownloadEnabled"
}

/// User-selectable app theme. Mirrors `ColorScheme?` but needs to be its own
/// `String`-backed enum so it can round-trip through `@AppStorage`.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// `nil` tells SwiftUI to defer to the system setting, matching `.system`.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Fixed set of chat wallpaper tints the user can pick between, reusing the same
/// hex-string approach as `StatusPalette` so `Color(hex:)` handles both. Empty
/// string represents "no tint — use the default system background".
enum WallpaperPalette {
    static let hexColors = [
        "#0A84FF", "#34C759", "#FF9F0A", "#FF375F",
        "#AF52DE", "#5E5CE6", "#8E8E93"
    ]
}
