import SwiftUI

/// Places keys on a fixed grid. Positions are animatable: when the spec changes (basic → scientific)
/// SwiftUI slides every surviving key to its new cell.
nonisolated struct KeyGridLayout: Layout {
    var spec: KeyGridSpec
    var spacing: CGFloat
    /// Extra gap after `spec.gutterAfterColumn` (the Book-pose channel).
    var centerGutter: CGFloat
    var keySize: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: keySize.width * CGFloat(spec.columns) + spacing * CGFloat(spec.columns - 1) + centerGutter,
               height: keySize.height * CGFloat(spec.rows) + spacing * CGFloat(spec.rows - 1))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            guard let placement = subview[KeyPlacementKey.self] else { continue }
            var x = bounds.minX + CGFloat(placement.column) * (keySize.width + spacing)
            if let gutterColumn = spec.gutterAfterColumn, placement.column >= gutterColumn {
                x += centerGutter
            }
            let y = bounds.minY + CGFloat(placement.row) * (keySize.height + spacing)
            let width = keySize.width * CGFloat(placement.columnSpan) + spacing * CGFloat(placement.columnSpan - 1)
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: keySize.height))
        }
    }
}

nonisolated struct KeyPlacementKey: LayoutValueKey {
    static let defaultValue: KeyPlacement? = nil
}

extension View {
    func keyPlacement(_ placement: KeyPlacement) -> some View {
        layoutValue(key: KeyPlacementKey.self, value: placement)
    }
}
