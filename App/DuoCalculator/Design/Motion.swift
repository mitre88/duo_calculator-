import SwiftUI

/// All animation curves in one place (so the fold morph, key presses and digit changes feel like one system).
enum Motion {
    /// Layout changes when the device folds/unfolds or the mode switches.
    static let layout: Animation = .spring(response: 0.5, dampingFraction: 0.82)
    /// Key press highlight.
    static let keyPress: Animation = .spring(response: 0.22, dampingFraction: 0.7)
    /// Digit roll in the display.
    static let digits: Animation = .snappy(duration: 0.22)
    /// Panels sliding in from the trailing edge.
    static let panel: Animation = .spring(response: 0.45, dampingFraction: 0.86)

    static func layout(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : layout
    }

    static func digits(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : digits
    }
}
