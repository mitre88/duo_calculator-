/// Memory register keys.
public enum MemoryAction: String, Sendable, Codable, Hashable, CaseIterable {
    case clear = "mc"
    case add = "mplus"
    case subtract = "mminus"
    case recall = "mr"
}

/// Everything the user can do to the calculator. The keypad, hardware keyboard and tests all speak this.
public enum CalculatorEvent: Sendable, Hashable, Codable {
    case digit(Int)
    case decimalSeparator
    /// `EE` — start typing a power-of-ten exponent.
    case exponentEntry
    /// `±`
    case toggleSign
    case percent
    case binary(BinaryOperator)
    /// Wraps the operand under the cursor: `30` → `sin(30)`.
    case function(UnaryFunction)
    /// `x!`, `x²`, `x³`
    case postfix(PostfixOperator)
    case constant(Constant)
    /// `Rand` — inserts a 16-digit random number in `[0, 1)`.
    case random
    case openParen
    case closeParen
    case equals
    /// `C` while typing, `AC` otherwise (see `DisplaySnapshot.clearLabel`).
    case clear
    case allClear
    case backspace
    case memory(MemoryAction)
    case setAngleMode(AngleMode)
    case toggleAngleMode
    case toggleSecond
    case cursorLeft
    case cursorRight
    case cursorToStart
    case cursorToEnd
    /// Move the cursor to a token boundary (0…tokens.count).
    case cursorTo(Int)
    /// Insert a value as an operand (unit converter, future history).
    case recall(CalcValue)
    /// Paste: the text is tokenized with the text grammar and inserted at the cursor.
    case insertText(String)
}

extension CalculatorEvent {
    /// Names used by `ios_sequences.json` and the `calc --keys` CLI.
    public init?(testName raw: String) {
        let name = raw.trimmingCharacters(in: .whitespaces)
        if name.count == 1, let d = Int(name) { self = .digit(d); return }
        switch name {
        case "dot", ".": self = .decimalSeparator
        case "ee": self = .exponentEntry
        case "neg", "±": self = .toggleSign
        case "pct", "%": self = .percent
        case "add", "+": self = .binary(.add)
        case "sub", "-", "−": self = .binary(.subtract)
        case "mul", "*", "×": self = .binary(.multiply)
        case "div", "/", "÷": self = .binary(.divide)
        case "pow", "^": self = .binary(.power)
        case "root": self = .binary(.root)
        case "logb": self = .binary(.logBase)
        case "rpow": self = .binary(.reversedPower)
        case "fact", "!": self = .postfix(.factorial)
        case "sq": self = .postfix(.square)
        case "cube": self = .postfix(.cube)
        case "pi": self = .constant(.pi)
        case "e": self = .constant(.e)
        case "rand": self = .random
        case "lp", "(": self = .openParen
        case "rp", ")": self = .closeParen
        case "eq", "=": self = .equals
        case "clear", "c": self = .clear
        case "ac": self = .allClear
        case "back": self = .backspace
        case "deg": self = .setAngleMode(.degrees)
        case "rad": self = .setAngleMode(.radians)
        case "angle": self = .toggleAngleMode
        case "second", "2nd": self = .toggleSecond
        case "left": self = .cursorLeft
        case "right": self = .cursorRight
        case "home": self = .cursorToStart
        case "end": self = .cursorToEnd
        default:
            if let memory = MemoryAction(rawValue: name) { self = .memory(memory); return }
            if let fn = UnaryFunction(rawValue: name) { self = .function(fn); return }
            return nil
        }
    }
}
