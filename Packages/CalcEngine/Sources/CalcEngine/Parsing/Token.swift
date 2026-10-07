import Foundation

/// Infix operators. Raw values are the text-grammar spellings.
public enum BinaryOperator: String, Sendable, Codable, Hashable, CaseIterable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case power = "^"
    /// `x ʸ√ y` — the y-th root of x (text form: `root(x, y)`).
    case root = "root"
    /// `x logᵧ y` — logarithm of x in base y (text form: `logb(x, y)`).
    case logBase = "logb"
    /// `x yˣ y` — y raised to x (the 2nd face of eˣ on iOS; text form: `rpow(x, y)`).
    case reversedPower = "rpow"

    /// Symbol shown in the expression line.
    public var displaySymbol: String {
        switch self {
        case .add: "+"
        case .subtract: "−"
        case .multiply: "×"
        case .divide: "÷"
        case .power: "^"
        case .root: "ʸ√"
        case .logBase: "logᵧ"
        case .reversedPower: "yˣ"
        }
    }

    /// Operators written as `name(a, b)` in text and in the expression line.
    public var isFunctionStyle: Bool { self == .root || self == .logBase || self == .reversedPower }
}

/// Postfix operators.
public enum PostfixOperator: String, Sendable, Codable, Hashable, CaseIterable {
    case factorial = "!"
    case percent = "%"
    case square = "²"
    case cube = "³"
}

/// Named constants.
public enum Constant: String, Sendable, Codable, Hashable, CaseIterable {
    case pi
    case e

    public var displaySymbol: String { self == .pi ? "π" : "e" }
}

/// A number exactly as the user typed it (so the display can echo `1.50` or `2e-` while editing).
public struct NumberLiteral: Sendable, Codable, Hashable {
    /// Digits with at most one `.`; never empty for a valid literal (`"0"`, `"12.5"`, `"0."`).
    public var mantissa: String
    public var isNegative: Bool
    /// `nil` = no `EE`; `""` = `EE` pressed and no digits yet; may carry a leading `-`.
    public var exponent: String?
    /// `true` for literals produced by the engine (results, memory recall, Rand): rendered with the
    /// display formatter instead of echoed verbatim, and replaced (not extended) by a typed digit.
    public var isComputed: Bool
    /// The exact engine value behind a computed literal (keeps the approx lane, so `√2 = x² − 2` is still 0).
    public var computedValue: CalcValue?

    public init(mantissa: String = "0", isNegative: Bool = false, exponent: String? = nil,
                isComputed: Bool = false, computedValue: CalcValue? = nil) {
        self.mantissa = mantissa
        self.isNegative = isNegative
        self.exponent = exponent
        self.isComputed = isComputed
        self.computedValue = computedValue
    }

    /// Parses a plain decimal literal such as `1.5e-3`, `-2`, `.25`.
    public init?(parsing text: String) {
        var body = text.trimmingCharacters(in: .whitespaces)
        var negative = false
        if body.hasPrefix("-") { negative = true; body.removeFirst() } else if body.hasPrefix("+") { body.removeFirst() }
        var exponent: String?
        if let eIndex = body.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            exponent = String(body[body.index(after: eIndex)...])
            body = String(body[..<eIndex])
        }
        guard !body.isEmpty,
              body.allSatisfy({ $0.isNumber || $0 == "." }),
              body.filter({ $0 == "." }).count <= 1 else { return nil }
        if let exponent {
            let digits = exponent.hasPrefix("-") || exponent.hasPrefix("+") ? String(exponent.dropFirst()) : exponent
            guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        }
        if body.hasPrefix(".") { body = "0" + body }
        self.init(mantissa: body, isNegative: negative, exponent: exponent?.replacingOccurrences(of: "+", with: ""))
    }

    /// `value` of a literal built from a `CalcValue` (used when a result becomes the next operand).
    public init(value: CalcValue, digits: Int = CalcPrecision.working) {
        let text = value.canonicalString(digits: digits)   // e.g. "-1.5E+3"
        var negative = false
        var body = text
        if body.hasPrefix("-") { negative = true; body.removeFirst() }
        let parts = body.split(separator: "E", maxSplits: 1).map(String.init)
        let mantissa = parts[0]
        let exp = parts.count > 1 ? parts[1].replacingOccurrences(of: "+", with: "") : nil
        self.init(mantissa: mantissa, isNegative: negative, exponent: (exp == nil || exp == "0") ? nil : exp,
                  isComputed: true, computedValue: value)
    }

    /// Machine-readable text (`-1.5e-3`); the exponent `""`/`"-"` is read as 0.
    public var text: String {
        var s = isNegative ? "-" : ""
        s += mantissa.hasSuffix(".") ? String(mantissa.dropLast()) : mantissa
        if let exponent, !exponent.isEmpty, exponent != "-" { s += "e" + exponent }
        return s
    }

    /// Exact value; `nil` when the literal has no digits yet.
    public var value: CalcValue? {
        if let computedValue { return isNegative == computedValue.isNegative ? computedValue : computedValue.negated }
        guard mantissa.contains(where: \.isNumber) else { return nil }
        return CalcValue(literal: text)
    }

    public var hasDecimalSeparator: Bool { mantissa.contains(".") }

    /// Number of significant digits typed so far (leading zeros excluded).
    public var significantDigitCount: Int {
        let digits = mantissa.filter(\.isNumber)
        let trimmed = digits.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? (digits.isEmpty ? 0 : 1) : trimmed.count
    }
}

/// One element of an expression. The keypad appends tokens directly; the text tokenizer produces the same tokens.
public enum Token: Sendable, Codable, Hashable {
    case number(NumberLiteral)
    case constant(Constant)
    case binary(BinaryOperator)
    /// `root(` / `logb(` text form: a two-argument function application.
    case namedBinary(BinaryOperator)
    case function(UnaryFunction)
    case openParen
    case closeParen
    case comma
    case postfix(PostfixOperator)

    /// Can this token end an operand? (Used for implicit multiplication and for `wrap` decisions.)
    public var endsOperand: Bool {
        switch self {
        case .number, .constant, .closeParen, .postfix: true
        default: false
        }
    }

    /// Can this token start an operand?
    public var startsOperand: Bool {
        switch self {
        case .number, .constant, .function, .namedBinary, .openParen: true
        default: false
        }
    }

    public var numberLiteral: NumberLiteral? {
        if case .number(let literal) = self { return literal }
        return nil
    }

    public var isBinaryOperator: Bool {
        if case .binary = self { return true }
        return false
    }
}
