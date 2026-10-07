/// Renders tokens into display segments (`2 + sin(30) × π`), optionally with a cursor marker.
public enum ExpressionRenderer {
    public static func render(_ tokens: [Token], cursor: Int?, formatter: DisplayFormatter) -> [DisplaySegment] {
        var segments: [DisplaySegment] = []
        var nextID = 0
        func append(_ text: String, _ kind: DisplaySegment.Kind, _ index: Int?) {
            segments.append(DisplaySegment(id: nextID, text: text, kind: kind, tokenIndex: index))
            nextID += 1
        }
        for (index, token) in tokens.enumerated() {
            if cursor == index { append("", .cursor, nil) }
            switch token {
            case .number(let literal):
                append(formatter.formatEntry(literal), .number, index)
            case .constant(let constant):
                append(constant.displaySymbol, .constant, index)
            case .binary(let op):
                let isPrefixMinus = op == .subtract && isPrefixPosition(tokens, index)
                if isPrefixMinus {
                    append("−", .binaryOperator, index)
                } else if op == .power {
                    append("^", .binaryOperator, index)
                } else {
                    append(" " + op.displaySymbol + " ", .binaryOperator, index)
                }
            case .namedBinary(let op):
                append(functionStyleName(op), .function, index)
            case .function(let fn):
                append(functionName(fn), .function, index)
            case .openParen:
                append("(", .parenthesis, index)
            case .closeParen:
                append(")", .parenthesis, index)
            case .comma:
                append(", ", .comma, index)
            case .postfix(let op):
                append(op.rawValue, .postfix, index)
            }
        }
        if cursor == tokens.count { append("", .cursor, nil) }
        return segments
    }

    public static func text(_ tokens: [Token], formatter: DisplayFormatter) -> String {
        render(tokens, cursor: nil, formatter: formatter).map(\.text).joined()
    }

    static func isPrefixPosition(_ tokens: [Token], _ index: Int) -> Bool {
        if index == 0 { return true }
        switch tokens[index - 1] {
        case .binary, .openParen, .comma, .namedBinary: return true
        default: return false
        }
    }

    static func functionName(_ fn: UnaryFunction) -> String {
        switch fn {
        case .sqrt: "√"
        case .cbrt: "∛"
        case .reciprocal: "1/"
        case .exp: "e^"
        case .pow10: "10^"
        case .pow2: "2^"
        case .square: "sq"
        case .cube: "cube"
        default: fn.displayName
        }
    }

    static func functionStyleName(_ op: BinaryOperator) -> String {
        switch op {
        case .root: "root"
        case .logBase: "log"
        case .reversedPower: "pow"
        default: op.displaySymbol
        }
    }
}
