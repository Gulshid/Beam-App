import SwiftUI

extension Color {
    /// Parses a "#RRGGBB" (or "RRGGBB") string. Falls back to a neutral gray for
    /// anything malformed rather than crashing — status backgrounds are cosmetic,
    /// not worth a hard failure over.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.removeAll { $0 == "#" }

        var value: UInt64 = 0
        guard sanitized.count == 6, Scanner(string: sanitized).scanHexInt64(&value) else {
            self = Color(.systemGray)
            return
        }

        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

/// Fixed palette the text-status composer cycles through, mirroring WhatsApp's
/// set of solid background colors for text-only statuses.
enum StatusPalette {
    static let hexColors = [
        "#0A84FF", "#34C759", "#FF9F0A", "#FF375F",
        "#AF52DE", "#5E5CE6", "#FF3B30", "#1C1C1E"
    ]
}
