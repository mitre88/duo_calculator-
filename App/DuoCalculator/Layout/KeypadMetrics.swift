import Foundation

/// Key-size model:  side = min((W − (n−1)·gap − 2·margin) / n, (H − (rows−1)·gap) / rows)
enum KeypadMetrics {
    static let minimumKeySide: CGFloat = 44
    static let defaultSpacing: CGFloat = 12
    static let compactSpacing: CGFloat = 8
    static let defaultMargin: CGFloat = 16
    static let compactMargin: CGFloat = 12

    static func keyWidth(available width: CGFloat, columns: Int, spacing: CGFloat, margin: CGFloat, gutter: CGFloat = 0) -> CGFloat {
        (width - 2 * margin - CGFloat(columns - 1) * spacing - gutter) / CGFloat(columns)
    }

    static func keyHeight(available height: CGFloat, rows: Int, spacing: CGFloat) -> CGFloat {
        (height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
    }

    static func keypadHeight(keyHeight: CGFloat, rows: Int, spacing: CGFloat) -> CGFloat {
        keyHeight * CGFloat(rows) + CGFloat(rows - 1) * spacing
    }
}

/// Display-stack model (top → bottom, see `DisplayView`):
///   topInset · mode bar · expression · preview · result · indicator pills · bottom padding
/// The preview row is always budgeted, so a result appearing mid-typing never pushes the stack into the keypad.
enum DisplayMetrics {
    static let minimumTopInset: CGFloat = 8
    /// Gap kept between the mode bar and a status bar / camera above it.
    static let obstacleClearance: CGFloat = 12

    /// The outer screen keeps a slightly smaller result floor so its circular keys still fit.
    static func minimumPrimaryLineHeight(compact: Bool) -> CGFloat { compact ? 44 : 64 }
    static func modeBarHeight(compact: Bool) -> CGFloat { compact ? 36 : 44 }
    static func expressionHeight(compact: Bool) -> CGFloat { compact ? 28 : 34 }
    static func previewHeight(compact: Bool) -> CGFloat { compact ? 22 : 26 }
    static let indicatorHeight: CGFloat = 22
    static let bottomPadding: CGFloat = 6
    static func stackSpacing(compact: Bool) -> CGFloat { compact ? 4 : 8 }

    /// Everything in the display except the top inset and the result line.
    static func chromeHeight(compact: Bool) -> CGFloat {
        modeBarHeight(compact: compact) + expressionHeight(compact: compact) + previewHeight(compact: compact)
            + indicatorHeight + bottomPadding + 5 * stackSpacing(compact: compact)
    }

    /// Smallest display that shows its whole stack, including a legible result line.
    static func minimumHeight(topInset: CGFloat, compact: Bool) -> CGFloat {
        topInset + chromeHeight(compact: compact) + minimumPrimaryLineHeight(compact: compact)
    }

    /// Result font size for a given line height (rounded light digits are ~1.2× their point size tall).
    static func primaryFontSize(lineHeight: CGFloat, compact: Bool) -> CGFloat {
        min(compact ? 76 : 96, max(28, lineHeight / 1.2))
    }
}
