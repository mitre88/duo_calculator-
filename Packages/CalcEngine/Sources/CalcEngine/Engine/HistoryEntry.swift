import Foundation

/// One committed calculation: the expression shown with `=` and its result. Rendered by the History
/// panel with `ExpressionRenderer.text(_:formatter:)`, so it follows the current locale and grouping.
public struct HistoryEntry: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    /// The committed expression; empty when it was too long to keep (the result is always kept).
    public var tokens: [Token]
    public var result: CalcValue
    public var date: Date

    /// Fifty entries of at most 1 KB keep the persisted state small, whatever the user computes.
    public static let maxEncodedBytes = 1024

    public init(id: UUID = UUID(), tokens: [Token], result: CalcValue, date: Date) {
        self.id = id
        self.tokens = tokens
        self.result = result
        self.date = date
    }

    /// A long or huge expression keeps only its result; a huge exact result keeps its working-precision approximation.
    mutating func fitToStorageBudget() {
        guard encodedSize > Self.maxEncodedBytes else { return }
        tokens = []
        if encodedSize > Self.maxEncodedBytes {
            result = CalcValue(approx: result.approx)
        }
    }

    private var encodedSize: Int {
        (try? JSONEncoder().encode(self).count) ?? .max
    }
}

/// Clock for history timestamps, injected like `RandomSource` so tests stay deterministic.
public protocol DateSource: Sendable {
    func now() -> Date
}

public struct SystemDateSource: DateSource {
    public init() {}

    public func now() -> Date { Date() }
}
