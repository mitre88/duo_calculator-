import SwiftUI

/// A reserved region reported by the system: the fold (`division`) or a camera (`occlusion`).
struct ReservedRegionInfo: Equatable {
    enum Kind: Hashable { case division, occlusion }
    enum Axis: Hashable { case horizontal, vertical }

    var kind: Kind
    /// In the coordinate space of the view that queried it.
    var frame: CGRect
    /// Extra breathing room the system recommends around the region.
    var margins: EdgeInsets
    var isActive: Bool

    /// A horizontal division spans the width (Laptop pose); a vertical one spans the height (Book pose).
    var axis: Axis { frame.width >= frame.height ? .horizontal : .vertical }

    /// `frame` grown by `margins`.
    var expandedFrame: CGRect {
        CGRect(x: frame.minX - margins.leading,
               y: frame.minY - margins.top,
               width: frame.width + margins.leading + margins.trailing,
               height: frame.height + margins.top + margins.bottom)
    }
}

/// Everything `LayoutResolver` needs. Built by `CalculatorRootView` from the environment and a `GeometryProxy`.
struct LayoutInput: Equatable {
    var size: CGSize
    var safeArea: EdgeInsets
    var sizeClass: SizeClassPair
    var regions: [ReservedRegionInfo]
    var isAccessibilitySize: Bool
    var prefersScientificInCompactLandscape: Bool

    init(size: CGSize,
         safeArea: EdgeInsets = EdgeInsets(),
         sizeClass: SizeClassPair,
         regions: [ReservedRegionInfo] = [],
         isAccessibilitySize: Bool = false,
         prefersScientificInCompactLandscape: Bool = true) {
        self.size = size
        self.safeArea = safeArea
        self.sizeClass = sizeClass
        self.regions = regions
        self.isAccessibilitySize = isAccessibilitySize
        self.prefersScientificInCompactLandscape = prefersScientificInCompactLandscape
    }

    /// Content rectangle inside the safe area.
    var contentRect: CGRect {
        CGRect(x: safeArea.leading,
               y: safeArea.top,
               width: max(0, size.width - safeArea.leading - safeArea.trailing),
               height: max(0, size.height - safeArea.top - safeArea.bottom))
    }

    var activeHorizontalDivision: ReservedRegionInfo? {
        regions.first { $0.kind == .division && $0.isActive && $0.axis == .horizontal }
    }

    /// Any vertical fold, active or not (the HIG asks for an even column count whenever one exists).
    var verticalDivision: ReservedRegionInfo? {
        regions.first { $0.kind == .division && $0.axis == .vertical }
    }

    var activeOcclusions: [ReservedRegionInfo] {
        regions.filter { $0.kind == .occlusion && $0.isActive }
    }
}
