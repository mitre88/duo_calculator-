/// What `=` repeats: `2 + 3 = = =` → `+ 3` applied again and again.
public struct RepeatOperation: Sendable, Codable, Hashable {
    public var op: BinaryOperator
    public var operand: CalcValue

    public init(op: BinaryOperator, operand: CalcValue) {
        self.op = op
        self.operand = operand
    }
}

/// Persistent state of the calculator (`Codable` so a fold, a relaunch or a scene restore keeps everything).
public struct CalculatorState: Sendable, Codable, Hashable {
    public enum Phase: Sendable, Codable, Hashable {
        /// Empty document, display shows `0`.
        case idle
        /// The number right before the cursor is being typed.
        case entering
        /// A function, postfix, constant, `MR` or `%` just produced the operand before the cursor; a digit replaces it.
        case operandComputed
        /// A binary operator was just inserted.
        case operatorPending
        /// Generic editing (after cursor moves, parentheses, paste).
        case editing
        /// `=` was pressed; the document holds the result as a computed literal.
        case resultShown
        case error(CalcError)
    }

    public var phase: Phase = .idle
    public var document = ExpressionDocument()
    /// The expression that produced `lastResult` (shown with a trailing `=`).
    public var committedTokens: [Token] = []
    public var repeatOperation: RepeatOperation?
    public var memory: CalcValue = .zero
    public var angleMode: AngleMode = .degrees
    public var isSecondActive = false
    public var lastResult: CalcValue?
    /// Most recent results (newest last, capped) — the future history panel only needs UI.
    public var results: [CalcValue] = []

    public static let maxStoredResults = 50

    public init() {}

    public var isError: Bool {
        if case .error = phase { return true }
        return false
    }

    public var isEntering: Bool { phase == .entering }
}
