/// One rendered piece of the expression line. `tokenIndex` lets the UI place the cursor on tap.
public struct DisplaySegment: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case number, constant, binaryOperator, function, parenthesis, postfix, comma, cursor, equals
    }

    public var id: Int
    public var text: String
    public var kind: Kind
    /// Index of the token in the document (`nil` for the cursor and the `=` sign).
    public var tokenIndex: Int?

    public init(id: Int, text: String, kind: Kind, tokenIndex: Int?) {
        self.id = id
        self.text = text
        self.kind = kind
        self.tokenIndex = tokenIndex
    }
}

/// Everything the display needs. Produced by `CalculatorEngine.snapshot(formatter:)`.
public struct DisplaySnapshot: Sendable, Hashable {
    public enum ClearLabel: String, Sendable, Hashable {
        case clear = "C"
        case allClear = "AC"
    }

    public var expression: [DisplaySegment]
    public var expressionText: String
    /// Main line: the number being typed, the operand just computed, the pending operand, or the result.
    public var primary: String
    public var primaryValue: CalcValue?
    /// Live result of the whole expression while it is being typed (`nil` when it equals `primary` or cannot be evaluated).
    public var preview: String?
    public var isError: Bool
    public var errorReason: CalcError?
    public var clearLabel: ClearLabel
    public var memoryActive: Bool
    public var angleMode: AngleMode
    public var isSecondActive: Bool
    /// Operator key to highlight (the one just pressed).
    public var pendingOperator: BinaryOperator?
    public var cursor: Int
    public var tokenCount: Int
    /// `true` right after `=`: the expression line ends with `=` and `primary` is the result.
    public var showsResult: Bool
    public var isEntering: Bool

    public static let empty = DisplaySnapshot(
        expression: [], expressionText: "", primary: "0", primaryValue: .zero, preview: nil,
        isError: false, errorReason: nil, clearLabel: .allClear, memoryActive: false,
        angleMode: .degrees, isSecondActive: false, pendingOperator: nil, cursor: 0, tokenCount: 0,
        showsResult: false, isEntering: false)
}
