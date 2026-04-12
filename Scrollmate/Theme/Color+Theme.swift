import SwiftUI

extension Color {
    // Background — pure black to match iOS Clock app aesthetic
    static let appBackground = Color(lightHex: "#F8F8F8", darkHex: "#000000")

    // Surface — cards, sheets, grouped sections
    static let appSurface = Color(lightHex: "#F0F0F0", darkHex: "#1C1C1C")

    // Border — dividers, input outlines
    static let appBorder = Color(lightHex: "#E0E0E0", darkHex: "#2E2E2E")

    // Text Primary — titles, body
    static let appTextPrimary = Color(lightHex: "#111111", darkHex: "#F8F8F8")

    // Text Secondary — captions, placeholders
    static let appTextSecondary = Color(hex: "#888888")

    // Accent — single point color
    static let appAccent = Color(hex: "#3A6EA8")

    // Tab bar background
    static let appTabBar = Color(hex: "#1A1A1A")

    // Inactive tab icon color
    static let appTabInactive = Color(hex: "#555555")
}

extension Color {
    // Adaptive color using UIColor hex directly inside the trait closure — avoids
    // SwiftUI Color → UIColor conversion which requires main thread
    init(lightHex: String, darkHex: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hexString: darkHex)
                : UIColor(hexString: lightHex)
        })
    }

    // Hex initializer for static (non-adaptive) colors
    init(hex: String) {
        self.init(uiColor: UIColor(hexString: hex))
    }
}

private extension UIColor {
    // UIColor hex initializer — supports "#RRGGBB" format
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(hex, radix: 16) ?? 0
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
