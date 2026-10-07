import Foundation

/// Which arrangement the calculator uses. Derived only from size classes, measured size and
/// reserved regions — never from orientation, idiom or screen size (Apple's iPhone Duo guidance).
enum LayoutMode: String, Hashable, Codable, CaseIterable {
    /// Compact width, regular height (outer display portrait, Split View ½): basic 4×5 keypad.
    case basic
    /// Compact width *and* compact height (outer display landscape): display leading, basic keys trailing.
    case basicLandscape
    /// Compact/compact with the "scientific in landscape" preference: 10×5 keypad with short keys.
    case scientificCompact
    /// Regular width (inner display): 10×5 scientific keypad under the display.
    case scientific
    /// Medium width (Split View ⅔): function block above the basic keypad.
    case scientificStacked
    /// Partially folded with a horizontal hinge (Laptop pose): display above the fold, keypad below it.
    case tabletop

    var isScientific: Bool {
        switch self {
        case .basic, .basicLandscape: false
        default: true
        }
    }
}

enum SizeClass: Hashable, Codable {
    case compact, regular
}

struct SizeClassPair: Hashable, Codable {
    var horizontal: SizeClass
    var vertical: SizeClass

    static let compactRegular = SizeClassPair(horizontal: .compact, vertical: .regular)
    static let compactCompact = SizeClassPair(horizontal: .compact, vertical: .compact)
    static let regularRegular = SizeClassPair(horizontal: .regular, vertical: .regular)
}
