import Foundation

/// A History entry ready for display, formatted like `DisplaySnapshot` with the display's own formatter
/// (so it follows the locale, grouping and precision of the moment it is shown).
public struct HistoryRow: Sendable, Hashable, Identifiable {
    public let id: UUID
    /// `nil` when the expression was too long to keep (`HistoryEntry.tokens` is empty).
    public let expression: String?
    public let result: String
    /// The exact value, for reuse with `CalculatorEvent.recall`.
    public let value: CalcValue
    public let date: Date
}

extension CalculatorEngine {
    /// History rows, newest first.
    public func historyRows(formatter: DisplayFormatter) -> [HistoryRow] {
        state.history.reversed().map { entry in
            HistoryRow(id: entry.id,
                       expression: entry.tokens.isEmpty ? nil : ExpressionRenderer.text(entry.tokens, formatter: formatter),
                       result: formatter.format(entry.result),
                       value: entry.result,
                       date: entry.date)
        }
    }
}
