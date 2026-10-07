import SwiftUI

/// Type scale. SF Pro Rounded for keys, light rounded monospaced digits for the result.
enum Typography {
    static func primary(size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .rounded)
    }

    static func expression(compact: Bool) -> Font {
        .system(size: compact ? 20 : 24, weight: .medium, design: .rounded)
    }

    static func preview(compact: Bool) -> Font {
        .system(size: compact ? 17 : 20, weight: .regular, design: .rounded)
    }

    static func digitKey(keyHeight: CGFloat) -> Font {
        .system(size: min(36, max(20, keyHeight * 0.44)), weight: .regular, design: .rounded)
    }

    static func operatorKey(keyHeight: CGFloat) -> Font {
        .system(size: min(32, max(18, keyHeight * 0.40)), weight: .medium, design: .rounded)
    }

    static func functionKey(keyHeight: CGFloat) -> Font {
        // Small faces (tabletop, Book pose) go one weight up so they stay crisp on glass.
        let size = min(21, max(13, keyHeight * 0.30))
        return .system(size: size, weight: size < 17 ? .semibold : .medium, design: .rounded)
    }

    static func indicator() -> Font {
        .system(size: 13, weight: .semibold, design: .rounded)
    }

    /// Primary font size that fits the display box.
    static func primarySize(displayHeight: CGFloat, compact: Bool) -> CGFloat {
        min(compact ? 76 : 96, max(40, displayHeight * 0.40))
    }
}
