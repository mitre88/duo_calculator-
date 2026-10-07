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
    /// Scientific keys materializing during the unfold morph (per key, staggered with `stagger`).
    static let materialize: Animation = .spring(response: 0.42, dampingFraction: 0.84)
    /// Keys leaving when the device folds: fast, so the basic keypad settles first.
    static let dematerialize: Animation = .easeOut(duration: 0.14)

    static func layout(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : layout
    }

    static func digits(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : digits
    }

    // MARK: Fold choreography

    /// Delay for a key materializing at (row, column). The wave starts at the hinge (the gutter column
    /// when the grid has one, else the keypad's center line) and spreads outwards, one row after the
    /// other:  delay = min(0.14, 0.016·|column − origin| + 0.012·row).
    static func stagger(row: Int, column: Int, columns: Int, gutterAfterColumn: Int?) -> Double {
        let origin = Double(gutterAfterColumn ?? (columns / 2)) - 0.5
        let distance = abs(Double(column) - origin)
        return min(0.14, distance * 0.016 + Double(row) * 0.012)
    }

    /// Insertion / removal transition of a key, staggered along the fold wave.
    static func keyTransition(row: Int, column: Int, columns: Int, gutterAfterColumn: Int?, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let delay = stagger(row: row, column: column, columns: columns, gutterAfterColumn: gutterAfterColumn)
        return .asymmetric(
            insertion: .scale(scale: 0.86).combined(with: .opacity).animation(materialize.delay(delay)),
            removal: .opacity.animation(dematerialize))
    }
}
