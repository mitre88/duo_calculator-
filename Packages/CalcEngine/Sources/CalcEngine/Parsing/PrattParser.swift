/// Pratt (top-down operator precedence) parser over `[Token]`.
///
/// Besides strict parsing it supports two calculator behaviours:
/// * **auto-close**: a missing `)` at the end is implied (`(2 + 3 × 4 =` → 14);
/// * **trailing operator** policies: `2 + 3 ×` can be rejected (text), previewed as the operand the
///   operator would bind to (`3`), or completed by duplicating that operand (`= ` → `2 + 3 × 3 = 11`).
public struct PrattParser {
    public enum TrailingOperatorPolicy: Sendable {
        case reject
        case previewLeftOperand
        case duplicateLeftOperand
    }

    public struct Options: Sendable {
        public var autoCloseParentheses: Bool
        public var trailingOperator: TrailingOperatorPolicy

        public init(autoCloseParentheses: Bool = false, trailingOperator: TrailingOperatorPolicy = .reject) {
            self.autoCloseParentheses = autoCloseParentheses
            self.trailingOperator = trailingOperator
        }

        /// Strict text parsing (tests, CLI, paste).
        public static let strict = Options()
        /// Live preview while typing.
        public static let preview = Options(autoCloseParentheses: true, trailingOperator: .previewLeftOperand)
        /// The `=` key.
        public static let commit = Options(autoCloseParentheses: true, trailingOperator: .duplicateLeftOperand)
    }

    public static func parse(_ tokens: [Token], options: Options = .strict) throws -> Expr {
        var parser = PrattParser(tokens: tokens, options: options, focusEnd: nil)
        return try parser.parseExpression()
    }

    /// Result of `parseWithFocus`: the whole expression plus the operand that ends right before
    /// token index `focusEnd`, resolved in context (a `b%` right operand of `a ± b%` becomes `a × b%`).
    public struct FocusedParse: Sendable {
        public var expression: Expr
        public var focus: Expr?
        /// The binary operation whose operator token comes last in the input (what `=` repeats).
        public var lastBinary: LastBinary?
    }

    public struct LastBinary: Sendable, Hashable {
        public var op: BinaryOperator
        public var rhs: Expr
        public var operatorIndex: Int
    }

    /// Parses and also extracts the operand ending at `focusEnd` (usually the cursor), so the
    /// display can show `20` for `200 + 10%` or `0.5` for `sin(30)` right after the key press.
    public static func parseWithFocus(_ tokens: [Token], focusEnd: Int, options: Options = .preview) throws -> FocusedParse {
        var parser = PrattParser(tokens: tokens, options: options, focusEnd: focusEnd)
        let expression = try parser.parseExpression()
        return FocusedParse(expression: expression, focus: parser.focus ?? parser.focusCandidate, lastBinary: parser.lastBinary)
    }

    private let tokens: [Token]
    private let options: Options
    private let focusEnd: Int?
    private var position = 0
    private var depth = 0
    private var previewNode: Expr?
    /// Innermost operand ending exactly at `focusEnd` (set bottom-up, first writer wins).
    private var focusCandidate: Expr?
    /// `focusCandidate` resolved by its parent binary operator (percent context).
    private var focus: Expr?
    private var lastBinary: LastBinary?

    private mutating func noteLastBinary(_ op: BinaryOperator, rhs: Expr, operatorIndex: Int) {
        if let lastBinary, lastBinary.operatorIndex >= operatorIndex { return }
        lastBinary = LastBinary(op: op, rhs: rhs, operatorIndex: operatorIndex)
    }

    private init(tokens: [Token], options: Options, focusEnd: Int?) {
        self.tokens = tokens
        self.options = options
        self.focusEnd = focusEnd
    }

    private mutating func noteOperand(_ node: Expr) {
        guard let focusEnd, focusCandidate == nil, position == focusEnd else { return }
        focusCandidate = node
    }

    private mutating func noteBinary(_ op: BinaryOperator, lhs: Expr, rhs: Expr, rhsWasFocus: Bool) {
        guard rhsWasFocus, focus == nil else { return }
        if case .postfix(.percent, _) = rhs {
            switch op {
            case .add, .subtract: focus = .binary(.multiply, lhs, rhs)
            default: focus = rhs
            }
        } else {
            focus = rhs
        }
    }

    private var current: Token? { position < tokens.count ? tokens[position] : nil }

    private mutating func parseExpression() throws -> Expr {
        guard !tokens.isEmpty else { throw CalcError.syntax }
        guard tokens.count <= OperatorTable.maxTokens else { throw CalcError.tooComplex }
        let expression = try parse(minBindingPower: 0)
        if let previewNode { return previewNode }
        guard position == tokens.count else { throw CalcError.syntax }
        return expression
    }

    private var atTrailingPosition: Bool {
        guard let token = current else { return true }
        switch token {
        case .closeParen, .comma: return true
        default: return false
        }
    }

    private mutating func parse(minBindingPower: Int) throws -> Expr {
        var lhs = try parsePrefix()
        loop: while let token = current {
            switch token {
            case .postfix(let op):
                if OperatorTable.postfix < minBindingPower { break loop }
                position += 1
                lhs = .postfix(op, lhs)
                noteOperand(lhs)

            case .binary(let op):
                let (leftBP, rightBP) = OperatorTable.binding(op)
                if leftBP < minBindingPower { break loop }
                position += 1
                if atTrailingPosition {
                    switch options.trailingOperator {
                    case .reject:
                        throw CalcError.syntax
                    case .previewLeftOperand:
                        if previewNode == nil { previewNode = lhs }
                        return lhs
                    case .duplicateLeftOperand:
                        lhs = .binary(op, lhs, lhs)
                        noteLastBinary(op, rhs: lhs, operatorIndex: position)
                    }
                } else {
                    let hadCandidate = focusCandidate != nil
                    let rhs = try parse(minBindingPower: rightBP)
                    let rhsWasFocus = !hadCandidate && focusCandidate != nil && focus == nil && isFocusCandidate(rhs)
                    let left = lhs
                    lhs = .binary(op, left, rhs)
                    noteBinary(op, lhs: left, rhs: rhs, rhsWasFocus: rhsWasFocus)
                    noteLastBinary(op, rhs: rhs, operatorIndex: position)
                }

            case .number, .constant, .function, .namedBinary, .openParen:
                // implicit multiplication: 2π, 3(4+1), 2sin(30)
                let (leftBP, rightBP) = OperatorTable.implicitMultiplication
                if leftBP < minBindingPower { break loop }
                let rhs = try parse(minBindingPower: rightBP)
                lhs = .binary(.multiply, lhs, rhs)

            case .closeParen, .comma:
                break loop
            }
        }
        return lhs
    }

    private mutating func parsePrefix() throws -> Expr {
        guard let token = current else { throw CalcError.syntax }
        position += 1
        switch token {
        case .number(let literal):
            guard let value = literal.value else { throw CalcError.syntax }
            let node = Expr.number(value)
            noteOperand(node)
            return node

        case .constant(let constant):
            let node = Expr.constant(constant)
            noteOperand(node)
            return node

        case .binary(.subtract):
            return .negate(try parse(minBindingPower: OperatorTable.prefixMinus))

        case .binary(.add):
            return try parse(minBindingPower: OperatorTable.prefixMinus)

        case .openParen:
            try enter()
            defer { depth -= 1 }
            let inner = try parse(minBindingPower: 0)
            try consumeCloseParen()
            let node = Expr.group(inner)
            noteOperand(node)
            return node

        case .function(let fn):
            if case .openParen? = current {
                position += 1
                try enter()
                defer { depth -= 1 }
                let inner = try parse(minBindingPower: 0)
                try consumeCloseParen()
                let node = Expr.function(fn, .group(inner))
                noteOperand(node)
                return node
            }
            // `sin 30`: binds tighter than × but looser than ^ and postfix
            return .function(fn, try parse(minBindingPower: OperatorTable.prefixFunction))

        case .namedBinary(let op):
            guard case .openParen? = current else { throw CalcError.syntax }
            position += 1
            try enter()
            defer { depth -= 1 }
            let first = try parse(minBindingPower: 0)
            guard case .comma? = current else { throw CalcError.syntax }
            position += 1
            let second = try parse(minBindingPower: 0)
            try consumeCloseParen()
            let node = Expr.binary(op, first, second)
            noteOperand(node)
            return node

        case .closeParen, .comma, .postfix, .binary:
            throw CalcError.syntax
        }
    }

    private func isFocusCandidate(_ node: Expr) -> Bool {
        guard let candidate = focusCandidate else { return false }
        return candidate == node
    }

    private mutating func enter() throws {
        depth += 1
        if depth > OperatorTable.maxDepth { throw CalcError.tooComplex }
    }

    private mutating func consumeCloseParen() throws {
        if case .closeParen? = current {
            position += 1
            return
        }
        if current == nil, options.autoCloseParentheses { return }
        throw CalcError.syntax
    }
}
