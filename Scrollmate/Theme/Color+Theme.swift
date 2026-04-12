import SwiftUI

// App is forced to dark mode via preferredColorScheme(.dark),
// so all colors are static dark values — no UITraitCollection closure needed.
extension Color {
    static let appBackground   = Color(hex: "#000000")
    static let appSurface      = Color(hex: "#1C1C1C")
    static let appBorder       = Color(hex: "#2E2E2E")
    static let appTextPrimary  = Color(hex: "#F8F8F8")
    static let appTextSecondary = Color(hex: "#888888")
    static let appAccent       = Color(hex: "#3A6EA8")
    static let appTabBar       = Color(hex: "#1A1A1A")
    static let appTabInactive  = Color(hex: "#555555")
}

extension Color {
    // Simple hex initializer — no UIColor, no trait closures, thread-safe
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(hex, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
