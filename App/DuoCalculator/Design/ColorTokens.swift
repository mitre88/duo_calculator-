import SwiftUI

/// Color tokens. Dark mode is first-class: the canvas is true OLED black (optional) with a faint
/// "aurora" mesh behind the glass so it has something to refract.
enum Palette {
    static func canvas(_ scheme: ColorScheme, trueBlack: Bool) -> Color {
        switch scheme {
        case .dark: trueBlack ? .black : Color(red: 0.043, green: 0.043, blue: 0.063)
        default: Color(red: 0.949, green: 0.949, blue: 0.969)
        }
    }

    static func functionTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    static func utilityTint(_ scheme: ColorScheme) -> Color {
        Color(red: 0.557, green: 0.557, blue: 0.576).opacity(scheme == .dark ? 0.45 : 0.35)
    }

    static func digitTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.35)
    }

    static func operatorTint(_ accent: Color) -> Color { accent.opacity(0.85) }

    static func activeTint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.92) : Color.white
    }

    static let error = Color(red: 1.0, green: 0.271, blue: 0.227)

    /// Mesh colors for the aurora background.
    static func auroraColors(_ scheme: ColorScheme, accent: Color) -> [Color] {
        let indigo = Color(red: 0.30, green: 0.28, blue: 0.90)
        let teal = Color(red: 0.16, green: 0.72, blue: 0.78)
        let base = scheme == .dark ? Color.black : Color.white
        return [
            base, indigo, base,
            teal, accent, indigo,
            base, teal, base,
        ]
    }
}
