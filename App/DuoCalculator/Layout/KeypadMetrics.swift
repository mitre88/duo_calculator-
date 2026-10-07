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
