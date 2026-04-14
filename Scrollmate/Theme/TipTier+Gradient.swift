import SwiftUI

extension TipTier {
    var ringGradient: AngularGradient? {
        switch self {
        case .none:
            return nil
        case .bronze:
            return AngularGradient(colors: [
                Color(hex: "#6b3a2a"),
                Color(hex: "#cd7f32"),
                Color(hex: "#e8a97e"),
                Color(hex: "#cd7f32"),
                Color(hex: "#8b4513"),
                Color(hex: "#cd7f32"),
                Color(hex: "#6b3a2a"),
            ], center: .center)
        case .silver:
            return AngularGradient(colors: [
                Color(hex: "#aaaaaa"),
                Color(hex: "#eeeeee"),
                Color(hex: "#bbbbbb"),
                Color(hex: "#ffffff"),
                Color(hex: "#999999"),
                Color(hex: "#dddddd"),
                Color(hex: "#aaaaaa"),
            ], center: .center)
        case .gold:
            return AngularGradient(colors: [
                Color(hex: "#B8860B"),
                Color(hex: "#FFD700"),
                Color(hex: "#FFFACD"),
                Color(hex: "#FFA500"),
                Color(hex: "#FFD700"),
                Color(hex: "#FFE066"),
                Color(hex: "#B8860B"),
            ], center: .center)
        case .emerald:
            return AngularGradient(colors: [
                Color(hex: "#7dd9aa"),
                Color(hex: "#d0fff0"),
                Color(hex: "#3ecf80"),
                Color(hex: "#b0f0d0"),
                Color(hex: "#10c060"),
                Color(hex: "#d0fff0"),
                Color(hex: "#7dd9aa"),
            ], center: .center)
        case .diamond:
            return AngularGradient(colors: [
                Color(hex: "#a8d8ff"),
                Color(hex: "#ffffff"),
                Color(hex: "#56b4f5"),
                Color(hex: "#e0f4ff"),
                Color(hex: "#1d8eff"),
                Color(hex: "#ffffff"),
                Color(hex: "#a8d8ff"),
            ], center: .center)
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .none:    return "tier.none"
        case .bronze:  return "tier.bronze"
        case .silver:  return "tier.silver"
        case .gold:    return "tier.gold"
        case .emerald: return "tier.emerald"
        case .diamond: return "tier.diamond"
        }
    }
}
