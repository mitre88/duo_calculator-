import SwiftUI
import CalcEngine

/// Pure function `LayoutInput → LayoutPlan`. Unit-tested with synthetic iPhone Duo poses.
enum LayoutResolver {
    static let scientificMinimumWidth: CGFloat = 560
    static let stackedMinimumWidth: CGFloat = 440
    static let stackedMinimumHeight: CGFloat = 720
    static let compactHeightThreshold: CGFloat = 500
    static let minimumDisplayHeight: CGFloat = 112

    static func resolve(_ input: LayoutInput) -> LayoutPlan {
        let content = input.contentRect
        let mode = chooseMode(input)
        switch mode {
        case .basic:
            return basicPlan(input, content: content)
        case .basicLandscape:
            return basicLandscapePlan(input, content: content)
        case .scientificCompact:
            return scientificPlan(input, content: content, mode: .scientificCompact)
        case .scientific:
            return scientificPlan(input, content: content, mode: .scientific)
        case .book:
            guard let fold = input.verticalDivision, fold.isActive else {
                return scientificPlan(input, content: content, mode: .scientific)
            }
            return bookPlan(input, content: content, fold: fold)
        case .scientificStacked:
            return stackedPlan(input, content: content)
        case .tabletop:
            return tabletopPlan(input, content: content)
        }
    }

    // MARK: Mode

    static func chooseMode(_ input: LayoutInput) -> LayoutMode {
        let content = input.contentRect
        let compactWidth = input.sizeClass.horizontal == .compact || content.width < stackedMinimumWidth
        let compactHeight = input.sizeClass.vertical == .compact || content.height < compactHeightThreshold
        if input.isAccessibilitySize { return compactHeight ? .basicLandscape : .basic }
        if compactWidth {
            if compactHeight { return input.prefersScientificInCompactLandscape ? .scientificCompact : .basicLandscape }
            return .basic
        }
        if let division = input.activeHorizontalDivision,
           division.frame.midY > content.minY + minimumDisplayHeight,
           division.frame.midY < content.maxY - 200 {
            return .tabletop
        }
        if let fold = input.verticalDivision, fold.isActive,
           fold.expandedFrame.minX > content.minX + 200, fold.expandedFrame.maxX < content.maxX - 200 {
            return .book
        }
        if content.width < scientificMinimumWidth {
            return content.height >= stackedMinimumHeight ? .scientificStacked : .basic
        }
        return .scientific
    }

    // MARK: Display

    /// Top inset that drops the mode bar below any active occlusion (status bar corner, camera) over the
    /// top strip of `area`, the horizontal extent of the display.
    static func displayTopInset(_ input: LayoutInput, area: CGRect, compact: Bool) -> CGFloat {
        let band = CGRect(x: area.minX, y: area.minY, width: area.width,
                          height: DisplayMetrics.minimumTopInset + DisplayMetrics.modeBarHeight(compact: compact))
        let lowest = input.activeOcclusions.map(\.expandedFrame).filter { $0.intersects(band) }.map { $0.maxY - area.minY }.max()
        guard let lowest else { return DisplayMetrics.minimumTopInset }
        return max(DisplayMetrics.minimumTopInset, lowest + DisplayMetrics.obstacleClearance)
    }

    /// Display height for the full-width modes: the preferred share of the pane, never less than what the display
    /// stack needs, and never so much that the keypad drops below `minimumKeySide`.
    static func displayHeight(preferred: CGFloat, topInset: CGFloat, compact: Bool, content: CGRect,
                              margin: CGFloat, rows: Int, spacing: CGFloat) -> CGFloat {
        let required = DisplayMetrics.minimumHeight(topInset: topInset, compact: compact)
        let minimumKeypad = KeypadMetrics.keypadHeight(keyHeight: KeypadMetrics.minimumKeySide, rows: rows, spacing: spacing)
        let ceiling = content.height - margin - minimumKeypad
        return max(minimumDisplayHeight, min(max(preferred, required), ceiling))
    }

    // MARK: Plans

    private static func basicPlan(_ input: LayoutInput, content: CGRect) -> LayoutPlan {
        let spacing = KeypadMetrics.defaultSpacing
        let margin = KeypadMetrics.defaultMargin
        let spec = KeyGridSpec.basic
        var keyWidth = KeypadMetrics.keyWidth(available: content.width, columns: spec.columns, spacing: spacing, margin: margin)
        keyWidth = min(keyWidth, 96)
        var keyHeight = keyWidth
        var shape = KeyShapeStyle.circle
        let topInset = displayTopInset(input, area: content, compact: true)
        let displayMinimum = Self.displayHeight(preferred: 0, topInset: topInset, compact: true, content: content,
                                           margin: margin, rows: spec.rows, spacing: spacing)
        let maxKeypadHeight = content.height - displayMinimum - margin
        if KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: spec.rows, spacing: spacing) > maxKeypadHeight {
            keyHeight = max(KeypadMetrics.minimumKeySide, KeypadMetrics.keyHeight(available: maxKeypadHeight, rows: spec.rows, spacing: spacing))
            shape = .roundedRectangle
        }
        let keypadHeight = KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: spec.rows, spacing: spacing)
        let keypadWidth = keyWidth * CGFloat(spec.columns) + spacing * CGFloat(spec.columns - 1)
        let keypadFrame = CGRect(x: content.midX - keypadWidth / 2,
                                 y: content.maxY - margin - keypadHeight,
                                 width: keypadWidth,
                                 height: keypadHeight)
        let displayFrame = CGRect(x: content.minX, y: content.minY, width: content.width, height: keypadFrame.minY - content.minY)
        return LayoutPlan(mode: .basic, contentRect: content, displayFrame: displayFrame, keypadFrame: keypadFrame,
                          keypadSpec: spec, secondaryKeypadFrame: nil, secondaryKeypadSpec: nil,
                          keySpacing: spacing, centerGutter: 0, keyShape: shape,
                          keySize: CGSize(width: keyWidth, height: keyHeight), displayProfile: .compact,
                          isCompactWidth: true, avoidRects: input.activeOcclusions.map(\.expandedFrame),
                          panelsAvailable: false, displayTopInset: topInset)
    }

    private static func basicLandscapePlan(_ input: LayoutInput, content: CGRect) -> LayoutPlan {
        // Display on the leading 40 %, keys on the trailing side (toward the thumb and the vertical bar).
        let spacing = KeypadMetrics.compactSpacing
        let margin = KeypadMetrics.compactMargin
        let spec = KeyGridSpec.basic
        let keypadAreaWidth = content.width * 0.6
        let keyHeight = max(KeypadMetrics.minimumKeySide,
                            KeypadMetrics.keyHeight(available: content.height - 2 * margin, rows: spec.rows, spacing: spacing))
        let keyWidth = min(KeypadMetrics.keyWidth(available: keypadAreaWidth, columns: spec.columns, spacing: spacing, margin: margin), keyHeight * 1.6)
        let keypadWidth = keyWidth * CGFloat(spec.columns) + spacing * CGFloat(spec.columns - 1)
        let keypadHeight = KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: spec.rows, spacing: spacing)
        let keypadFrame = CGRect(x: content.maxX - margin - keypadWidth,
                                 y: content.midY - keypadHeight / 2,
                                 width: keypadWidth, height: keypadHeight)
        let displayFrame = CGRect(x: content.minX, y: content.minY, width: keypadFrame.minX - content.minX, height: content.height)
        let topInset = displayTopInset(input, area: displayFrame, compact: true)
        return LayoutPlan(mode: .basicLandscape, contentRect: content, displayFrame: displayFrame, keypadFrame: keypadFrame,
                          keypadSpec: spec, secondaryKeypadFrame: nil, secondaryKeypadSpec: nil,
                          keySpacing: spacing, centerGutter: 0, keyShape: .roundedRectangle,
                          keySize: CGSize(width: keyWidth, height: keyHeight), displayProfile: .compact,
                          isCompactWidth: true, avoidRects: input.activeOcclusions.map(\.expandedFrame),
                          panelsAvailable: false, displayTopInset: topInset)
    }

    private static func scientificPlan(_ input: LayoutInput, content: CGRect, mode: LayoutMode) -> LayoutPlan {
        let spec = KeyGridSpec.scientific
        var spacing = mode == .scientificCompact ? KeypadMetrics.compactSpacing : 10
        var margin = mode == .scientificCompact ? KeypadMetrics.compactMargin : KeypadMetrics.defaultMargin
        let gutter: CGFloat = 0
        var keyWidth = KeypadMetrics.keyWidth(available: content.width, columns: spec.columns, spacing: spacing, margin: margin, gutter: gutter)
        if keyWidth < KeypadMetrics.minimumKeySide {
            spacing = KeypadMetrics.compactSpacing
            margin = KeypadMetrics.compactMargin
            keyWidth = KeypadMetrics.keyWidth(available: content.width, columns: spec.columns, spacing: spacing, margin: margin, gutter: gutter)
        }
        let compact = mode == .scientificCompact
        let topInset = displayTopInset(input, area: content, compact: compact)
        let displayHeight = Self.displayHeight(preferred: max(compact ? 90 : minimumDisplayHeight + 40, content.height * (compact ? 0.26 : 0.30)),
                                          topInset: topInset, compact: compact, content: content,
                                          margin: margin, rows: spec.rows, spacing: spacing)
        let keypadAreaHeight = content.height - displayHeight - margin
        var keyHeight = KeypadMetrics.keyHeight(available: keypadAreaHeight, rows: spec.rows, spacing: spacing)
        keyHeight = min(keyHeight, keyWidth * 1.45)
        keyHeight = max(keyHeight, KeypadMetrics.minimumKeySide)
        let keypadHeight = KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: spec.rows, spacing: spacing)
        let keypadWidth = keyWidth * CGFloat(spec.columns) + spacing * CGFloat(spec.columns - 1) + gutter
        let keypadFrame = CGRect(x: content.midX - keypadWidth / 2,
                                 y: content.maxY - margin - keypadHeight,
                                 width: keypadWidth, height: keypadHeight)
        let displayFrame = CGRect(x: content.minX, y: content.minY, width: content.width, height: keypadFrame.minY - content.minY)
        return LayoutPlan(mode: mode, contentRect: content, displayFrame: displayFrame, keypadFrame: keypadFrame,
                          keypadSpec: spec, secondaryKeypadFrame: nil, secondaryKeypadSpec: nil,
                          keySpacing: spacing, centerGutter: gutter, keyShape: .roundedRectangle,
                          keySize: CGSize(width: keyWidth, height: keyHeight),
                          displayProfile: mode == .scientificCompact ? .compact : .regular,
                          isCompactWidth: mode == .scientificCompact, avoidRects: input.activeOcclusions.map(\.expandedFrame),
                          panelsAvailable: mode == .scientific, displayTopInset: topInset)
    }

    /// Book pose: the 5 | 5 spec with the channel exactly over the fold's expanded frame. Each half is sized
    /// by the room beside the fold (the narrower side decides), so no key ever sits on the hinge.
    private static func bookPlan(_ input: LayoutInput, content: CGRect, fold: ReservedRegionInfo) -> LayoutPlan {
        let spec = KeyGridSpec.scientificBook
        let foldRect = fold.expandedFrame
        let leftColumns = spec.gutterAfterColumn ?? spec.columns / 2
        let rightColumns = spec.columns - leftColumns
        let leftRoom = max(0, foldRect.minX - content.minX)
        let rightRoom = max(0, content.maxX - foldRect.maxX)
        func fittedWidth(spacing: CGFloat, margin: CGFloat) -> CGFloat {
            let left = (leftRoom - margin - CGFloat(leftColumns - 1) * spacing) / CGFloat(leftColumns)
            let right = (rightRoom - margin - CGFloat(rightColumns - 1) * spacing) / CGFloat(rightColumns)
            return min(left, right)
        }
        var spacing: CGFloat = 10
        var margin = KeypadMetrics.defaultMargin
        var keyWidth = fittedWidth(spacing: spacing, margin: margin)
        if keyWidth < KeypadMetrics.minimumKeySide {
            spacing = KeypadMetrics.compactSpacing
            margin = KeypadMetrics.compactMargin
            keyWidth = fittedWidth(spacing: spacing, margin: margin)
        }
        // The channel (spacing + gutter) is derived after the spacing fallback, so it matches the fold exactly.
        let gutter = max(0, foldRect.width - spacing)
        let topInset = displayTopInset(input, area: content, compact: false)
        let displayHeight = Self.displayHeight(preferred: max(minimumDisplayHeight + 40, content.height * 0.30),
                                          topInset: topInset, compact: false, content: content,
                                          margin: margin, rows: spec.rows, spacing: spacing)
        let keypadAreaHeight = content.height - displayHeight - margin
        var keyHeight = KeypadMetrics.keyHeight(available: keypadAreaHeight, rows: spec.rows, spacing: spacing)
        keyHeight = max(min(keyHeight, keyWidth * 1.45), KeypadMetrics.minimumKeySide)
        let keypadHeight = KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: spec.rows, spacing: spacing)
        let leftBlockWidth = keyWidth * CGFloat(leftColumns) + spacing * CGFloat(leftColumns - 1)
        let rightBlockWidth = keyWidth * CGFloat(rightColumns) + spacing * CGFloat(rightColumns - 1)
        let keypadFrame = CGRect(x: foldRect.minX - leftBlockWidth,
                                 y: content.maxY - margin - keypadHeight,
                                 width: leftBlockWidth + spacing + gutter + rightBlockWidth,
                                 height: keypadHeight)
        let displayFrame = CGRect(x: content.minX, y: content.minY, width: content.width, height: keypadFrame.minY - content.minY)
        return LayoutPlan(mode: .book, contentRect: content, displayFrame: displayFrame, keypadFrame: keypadFrame,
                          keypadSpec: spec, secondaryKeypadFrame: nil, secondaryKeypadSpec: nil,
                          keySpacing: spacing, centerGutter: gutter, keyShape: .roundedRectangle,
                          keySize: CGSize(width: keyWidth, height: keyHeight), displayProfile: .regular,
                          isCompactWidth: false, avoidRects: input.activeOcclusions.map(\.expandedFrame),
                          panelsAvailable: false, displayTopInset: topInset)
    }

    private static func stackedPlan(_ input: LayoutInput, content: CGRect) -> LayoutPlan {
        let spacing = KeypadMetrics.compactSpacing
        let margin = KeypadMetrics.compactMargin
        let basic = KeyGridSpec.basic
        let block = KeyGridSpec.functionBlock
        let keyWidthBasic = KeypadMetrics.keyWidth(available: content.width, columns: basic.columns, spacing: spacing, margin: margin)
        let keyWidthBlock = KeypadMetrics.keyWidth(available: content.width, columns: block.columns, spacing: spacing, margin: margin)
        let totalRows = basic.rows + block.rows
        let topInset = displayTopInset(input, area: content, compact: false)
        let displayHeight = Self.displayHeight(preferred: max(minimumDisplayHeight, content.height * 0.22),
                                          topInset: topInset, compact: false, content: content,
                                          margin: margin + spacing, rows: totalRows, spacing: spacing)
        let available = content.height - displayHeight - margin - spacing
        let keyHeight = max(KeypadMetrics.minimumKeySide, min(keyWidthBasic, KeypadMetrics.keyHeight(available: available, rows: totalRows, spacing: spacing)))
        let basicHeight = KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: basic.rows, spacing: spacing)
        let blockHeight = KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: block.rows, spacing: spacing)
        let basicWidth = keyWidthBasic * CGFloat(basic.columns) + spacing * CGFloat(basic.columns - 1)
        let blockWidth = keyWidthBlock * CGFloat(block.columns) + spacing * CGFloat(block.columns - 1)
        let basicFrame = CGRect(x: content.midX - basicWidth / 2, y: content.maxY - margin - basicHeight, width: basicWidth, height: basicHeight)
        let blockFrame = CGRect(x: content.midX - blockWidth / 2, y: basicFrame.minY - spacing - blockHeight, width: blockWidth, height: blockHeight)
        let displayFrame = CGRect(x: content.minX, y: content.minY, width: content.width, height: blockFrame.minY - content.minY)
        return LayoutPlan(mode: .scientificStacked, contentRect: content, displayFrame: displayFrame, keypadFrame: basicFrame,
                          keypadSpec: basic, secondaryKeypadFrame: blockFrame, secondaryKeypadSpec: block,
                          keySpacing: spacing, centerGutter: 0, keyShape: .roundedRectangle,
                          keySize: CGSize(width: keyWidthBasic, height: keyHeight), displayProfile: .regular,
                          isCompactWidth: false, avoidRects: input.activeOcclusions.map(\.expandedFrame),
                          secondaryKeySize: CGSize(width: keyWidthBlock, height: keyHeight), displayTopInset: topInset)
    }

    private static func tabletopPlan(_ input: LayoutInput, content: CGRect) -> LayoutPlan {
        guard let fold = input.activeHorizontalDivision else { return scientificPlan(input, content: content, mode: .scientific) }
        let spacing = KeypadMetrics.compactSpacing
        let margin = KeypadMetrics.compactMargin
        let spec = KeyGridSpec.scientific
        let foldRect = fold.expandedFrame
        let lowerHalf = CGRect(x: content.minX, y: foldRect.maxY, width: content.width, height: max(0, content.maxY - foldRect.maxY))
        let upperHalf = CGRect(x: content.minX, y: content.minY, width: content.width, height: max(0, foldRect.minY - content.minY))
        let keyWidth = KeypadMetrics.keyWidth(available: lowerHalf.width, columns: spec.columns, spacing: spacing, margin: margin)
        var keyHeight = KeypadMetrics.keyHeight(available: lowerHalf.height - 2 * margin, rows: spec.rows, spacing: spacing)
        keyHeight = max(KeypadMetrics.minimumKeySide, min(keyHeight, keyWidth * 1.3))
        let keypadHeight = KeypadMetrics.keypadHeight(keyHeight: keyHeight, rows: spec.rows, spacing: spacing)
        let keypadWidth = keyWidth * CGFloat(spec.columns) + spacing * CGFloat(spec.columns - 1)
        let keypadFrame = CGRect(x: lowerHalf.midX - keypadWidth / 2,
                                 y: min(lowerHalf.minY + margin, lowerHalf.maxY - margin - keypadHeight),
                                 width: keypadWidth, height: keypadHeight)
        let topInset = displayTopInset(input, area: upperHalf, compact: false)
        return LayoutPlan(mode: .tabletop, contentRect: content, displayFrame: upperHalf, keypadFrame: keypadFrame,
                          keypadSpec: spec, secondaryKeypadFrame: nil, secondaryKeypadSpec: nil,
                          keySpacing: spacing, centerGutter: 0, keyShape: .roundedRectangle,
                          keySize: CGSize(width: keyWidth, height: keyHeight), displayProfile: .regular,
                          isCompactWidth: false, avoidRects: input.activeOcclusions.map(\.expandedFrame),
                          panelsAvailable: false, displayTopInset: topInset)
    }
}
