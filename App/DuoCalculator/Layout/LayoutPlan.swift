import SwiftUI
import CalcEngine

enum KeyShapeStyle: Hashable {
    case circle
    case roundedRectangle
}

/// The resolved geometry: where the display and the keypad(s) go and how the keys are shaped.
struct LayoutPlan: Equatable {
    var mode: LayoutMode
    var contentRect: CGRect
    var displayFrame: CGRect
    var keypadFrame: CGRect
    var keypadSpec: KeyGridSpec
    /// Function block above the basic keypad in `.scientificStacked`.
    var secondaryKeypadFrame: CGRect?
    var secondaryKeypadSpec: KeyGridSpec?
    var keySpacing: CGFloat
    /// Extra horizontal gap inserted after `keypadSpec.gutterAfterColumn` (Book pose), 0 otherwise.
    var centerGutter: CGFloat
    var keyShape: KeyShapeStyle
    var keySize: CGSize
    var displayProfile: DisplayProfile
    var isCompactWidth: Bool
    /// Regions the display text must stay clear of (the inner camera).
    var avoidRects: [CGRect]

    static let placeholder = LayoutPlan(
        mode: .basic,
        contentRect: CGRect(x: 0, y: 0, width: 382, height: 644),
        displayFrame: CGRect(x: 0, y: 0, width: 382, height: 220),
        keypadFrame: CGRect(x: 0, y: 220, width: 382, height: 424),
        keypadSpec: .basic,
        secondaryKeypadFrame: nil,
        secondaryKeypadSpec: nil,
        keySpacing: 12,
        centerGutter: 0,
        keyShape: .circle,
        keySize: CGSize(width: 76, height: 76),
        displayProfile: .compact,
        isCompactWidth: true,
        avoidRects: [])
}
