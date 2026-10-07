/// The expression being edited: a token list plus a cursor sitting between tokens.
public struct ExpressionDocument: Sendable, Codable, Hashable {
    public var tokens: [Token] = []
    /// `0…tokens.count`; the cursor sits between `tokens[cursor - 1]` and `tokens[cursor]`.
    public var cursor: Int = 0

    public init() {}

    public init(tokens: [Token]) {
        self.tokens = tokens
        self.cursor = tokens.count
    }

    public var isEmpty: Bool { tokens.isEmpty }

    public var tokenBeforeCursor: Token? { cursor > 0 && cursor <= tokens.count ? tokens[cursor - 1] : nil }

    public var tokenAfterCursor: Token? { cursor >= 0 && cursor < tokens.count ? tokens[cursor] : nil }

    /// Number of `(` minus number of `)`.
    public var parenthesisBalance: Int {
        tokens.reduce(0) { balance, token in
            switch token {
            case .openParen: balance + 1
            case .closeParen: balance - 1
            default: balance
            }
        }
    }

    public var containsBinaryOperator: Bool {
        tokens.contains { $0.isBinaryOperator }
    }

    /// A document that is just one number (typed or computed).
    public var singleNumber: NumberLiteral? {
        tokens.count == 1 ? tokens[0].numberLiteral : nil
    }

    // MARK: Mutation

    public mutating func insert(_ token: Token) {
        clampCursor()
        tokens.insert(token, at: cursor)
        cursor += 1
    }

    public mutating func insert(contentsOf newTokens: [Token]) {
        clampCursor()
        tokens.insert(contentsOf: newTokens, at: cursor)
        cursor += newTokens.count
    }

    public mutating func replace(_ range: Range<Int>, with newTokens: [Token]) {
        tokens.replaceSubrange(range, with: newTokens)
        cursor = range.lowerBound + newTokens.count
    }

    @discardableResult
    public mutating func removeBeforeCursor() -> Token? {
        clampCursor()
        guard cursor > 0 else { return nil }
        cursor -= 1
        return tokens.remove(at: cursor)
    }

    public mutating func clampCursor() {
        cursor = min(max(0, cursor), tokens.count)
    }

    public mutating func removeAll() {
        tokens.removeAll()
        cursor = 0
    }

    /// Edits the (typed) number literal right before the cursor. Returns `false` if there is none.
    @discardableResult
    public mutating func updateNumberBeforeCursor(_ body: (inout NumberLiteral) -> Void) -> Bool {
        guard cursor > 0, cursor <= tokens.count, case .number(var literal) = tokens[cursor - 1] else { return false }
        body(&literal)
        tokens[cursor - 1] = .number(literal)
        return true
    }

    // MARK: Operand detection

    /// Range of the complete operand that ends right before the cursor:
    /// a number/constant, a parenthesised group (with its leading function name), including trailing postfix operators.
    public func operandRangeBeforeCursor() -> Range<Int>? { operandRange(endingAt: cursor) }

    public func operandRange(endingAt end: Int) -> Range<Int>? {
        guard end > 0, end <= tokens.count else { return nil }
        var i = end
        while i > 0, case .postfix = tokens[i - 1] { i -= 1 }
        guard i > 0 else { return nil }
        switch tokens[i - 1] {
        case .number, .constant:
            return (i - 1)..<end
        case .closeParen:
            var depth = 0
            var j = i - 1
            while j >= 0 {
                switch tokens[j] {
                case .closeParen: depth += 1
                case .openParen: depth -= 1
                default: break
                }
                if depth == 0 { break }
                j -= 1
            }
            guard j >= 0 else { return nil }
            var start = j
            if start > 0 {
                switch tokens[start - 1] {
                case .function, .namedBinary: start -= 1
                default: break
                }
            }
            return start..<end
        default:
            return nil
        }
    }

    /// `true` when the token at `index` is a `−` acting as a prefix (start of expression, after an operator or `(`).
    public func isPrefixMinus(at index: Int) -> Bool {
        guard index >= 0, index < tokens.count, case .binary(.subtract) = tokens[index] else { return false }
        if index == 0 { return true }
        switch tokens[index - 1] {
        case .binary, .openParen, .comma, .namedBinary: return true
        default: return false
        }
    }
}
