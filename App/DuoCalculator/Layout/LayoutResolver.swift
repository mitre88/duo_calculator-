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
        if content.width < scientificMinimumWidth {
            return content.height >= stackedMinimumHeight ? .scientificStacked : .basic
        }
        return .scientific
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
        let maxKeypadHeight = content.height - minimumDisplayHeight - margin
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
                          isCompactWidth: true, avoidRects: input.activeOcclusions.map(\.expandedFrame))
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
        return LayoutPlan(mode: .basicLandscape, contentRect: content, displayFrame: displayFrame, keypadFrame: keypadFrame,
                          keypadSpec: spec, secondaryKeypadFrame: nil, secondaryKeypadSpec: nil,
                          keySpacing: spacing, centerGutter: 0, keyShape: .roundedRectangle,
                          keySize: CGSize(width: keyWidth, height: keyHeight), displayProfile: .compact,
                          isCompactWidth: true, avoidRects: input.activeOcclusions.map(\.expandedFrame))
    }

    private static func scientificPlan(_ input: LayoutInput, content: CGRect, mode: LayoutMode) -> LayoutPlan {
        let spec = KeyGridSpec.scientific
        var spacing = mode == .scientificCompact ? KeypadMetrics.compactSpacing : 10
        var margin = mode == .scientificCompact ? KeypadMetrics.compactMargin : KeypadMetrics.defaultMargin
        var gutter: CGFloat = 0
        if let fold = input.verticalDivision, mode == .scientific {
            // Book pose: widen the channel between the two halves to the fold's expanded width.
            gutter = max(0, fold.expandedFrame.width - spacing)
        }
        var keyWidth = KeypadMetrics.keyWidth(available: content.width, columns: spec.columns, spacing: spacing, margin: margin, gutter: gutter)
        if keyWidth < KeypadMetrics.minimumKeySide {
            spacing = KeypadMetrics.compactSpacing
            margin = KeypadMetrics.compactMargin
            keyWidth = KeypadMetrics.keyWidth(available: content.width, columns: spec.columns, spacing: spacing, margin: margin, gutter: gutter)
        }
        let displayHeight = max(mode == .scientificCompact ? 90 : minimumDisplayHeight + 40, content.height * (mode == .scientificCompact ? 0.26 : 0.30))
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
                          isCompactWidth: mode == .scientificCompact, avoidRects: input.activeOcclusions.map(\.expandedFrame))
    }

    private static func stackedPlan(_ input: LayoutInput, content: CGRect) -> LayoutPlan {
        let spacing = KeypadMetrics.compactSpacing
        let margin = KeypadMetrics.compactMargin
        let basic = KeyGridSpec.basic
        let block = KeyGridSpec.functionBlock
        let keyWidthBasic = KeypadMetrics.keyWidth(available: content.width, columns: basic.columns, spacing: spacing, margin: margin)
        let keyWidthBlock = KeypadMetrics.keyWidth(available: content.width, columns: block.columns, spacing: spacing, margin: margin)
        let displayHeight = max(minimumDisplayHeight, content.height * 0.22)
        let totalRows = basic.rows + block.rows
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
                          isCompactWidth: false, avoidRects: input.activeOcclusions.map(\.expandedFrame))
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
        return LayoutPlan(mode: .tabletop, contentRect: content, displayFrame: upperHalf, keypadFrame: keypadFrame,
                          keypadSpec: spec, secondaryKeypadFrame: nil, secondaryKeypadSpec: nil,
                          keySpacing: spacing, centerGutter: 0, keyShape: .roundedRectangle,
                          keySize: CGSize(width: keyWidth, height: keyHeight), displayProfile: .regular,
                          isCompactWidth: false, avoidRects: input.activeOcclusions.map(\.expandedFrame))
    }
}
