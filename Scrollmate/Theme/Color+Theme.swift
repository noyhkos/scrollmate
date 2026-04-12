import SwiftUI

extension Color {
    // Background — app-wide canvas
    static let appBackground = Color(light: Color(hex: "#F8F8F8"), dark: Color(hex: "#111111"))

    // Surface — cards, sheets, grouped sections
    static let appSurface = Color(light: Color(hex: "#F0F0F0"), dark: Color(hex: "#1C1C1C"))

    // Border — dividers, input outlines
    static let appBorder = Color(light: Color(hex: "#E0E0E0"), dark: Color(hex: "#2E2E2E"))

    // Text Primary — titles, body
    static let appTextPrimary = Color(light: Color(hex: "#111111"), dark: Color(hex: "#F8F8F8"))

    // Text Secondary — captions, placeholders (same value works on both modes)
    static let appTextSecondary = Color(hex: "#888888")
}

private extension Color {
    // Resolves to light or dark variant based on current color scheme
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    // Hex initializer — supports "#RRGGBB" format
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(hex, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
