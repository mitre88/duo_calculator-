/// Binary operators of the programmer calculator.
public enum ProgrammerOperator: String, Sendable, Codable, Hashable, CaseIterable {
    case and = "AND"
    case or = "OR"
    case xor = "XOR"
    case nor = "NOR"
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"
    case modulo = "mod"
    case shiftLeft = "<<"
    case shiftRight = ">>"
}

/// One-operand operations.
public enum ProgrammerUnary: String, Sendable, Codable, Hashable, CaseIterable {
    case not = "NOT"
    case negate = "±"
    case rotateLeft = "RoL"
    case rotateRight = "RoR"
    case shiftLeftOne = "<<1"
    case shiftRightOne = ">>1"
    case onesComplement = "1's"
    case twosComplement = "2's"
    case byteFlip = "byte flip"
    case wordFlip = "word flip"
}

public enum ProgrammerEvent: Sendable, Hashable, Codable {
    case digit(Int)             // 0…15 (validated against the radix)
    case backspace
    case clear
    case allClear
    case binary(ProgrammerOperator)
    case unary(ProgrammerUnary)
    case equals
    case setRadix(Radix)
    case setWidth(BitWidth)
    case toggleSigned
    case toggleBit(Int)
    case recall(ProgrammerValue)
}

/// Immediate-execution integer calculator (left to right, like most hardware programmer calculators).
public struct ProgrammerEngine: Sendable, Codable, Hashable {
    public var radix: Radix = .decimal
    public var width: BitWidth = .sixtyFour
    public var isSigned = true
    public private(set) var value = ProgrammerValue()
    public private(set) var entry: String?
    public private(set) var accumulator: ProgrammerValue?
    public private(set) var pendingOperator: ProgrammerOperator?
    public private(set) var isError = false
    public private(set) var lastOperand: ProgrammerValue?
    private var justEvaluated = false
    /// A new operand (digits, unary, bit toggle, recall) has been produced since the last operator.
    private var hasOperandSinceOperator = false

    public init() {}

    public var hasEntry: Bool { entry != nil }

    public mutating func send(_ event: ProgrammerEvent) {
        if isError {
            switch event {
            case .digit, .clear, .allClear, .recall: isError = false
            case .setRadix(let r): radix = r; isError = false; return
            case .setWidth(let w): applyWidth(w); isError = false; return
            case .toggleSigned: applySigned(!isSigned); isError = false; return
            default: return
            }
        }
        switch event {
        case .digit(let d):
            guard d >= 0, d < radix.rawValue else { return }
            if justEvaluated { accumulator = nil; pendingOperator = nil; justEvaluated = false }
            var text = entry ?? ""
            if text == "0" { text = "" }
            let maxDigits = maxEntryDigits
            guard text.count < maxDigits else { return }
            text.append(radix.validDigits[d])
            if let parsed = ProgrammerValue.parse(text, radix: radix, width: width, isSigned: isSigned) {
                entry = text
                value = parsed
                hasOperandSinceOperator = true
            }
        case .backspace:
            guard var text = entry, !text.isEmpty else { return }
            text.removeLast()
            if text.isEmpty || text == "-" {
                entry = nil
                value = value.with(bits: 0)
            } else if let parsed = ProgrammerValue.parse(text, radix: radix, width: width, isSigned: isSigned) {
                entry = text
                value = parsed
            }
        case .clear:
            if entry != nil {
                entry = nil
                value = value.with(bits: 0)
            } else {
                allClear()
            }
        case .allClear:
            allClear()
        case .binary(let op):
            if let pending = pendingOperator, let acc = accumulator, hasOperandSinceOperator {
                value = apply(pending, acc, value)
                if isError { return }
            }
            accumulator = value
            pendingOperator = op
            entry = nil
            justEvaluated = false
            hasOperandSinceOperator = false
        case .unary(let op):
            value = applyUnary(op, value)
            entry = nil
            hasOperandSinceOperator = true
        case .equals:
            guard let pending = pendingOperator, let acc = accumulator else { return }
            let operand = hasOperandSinceOperator ? value : (lastOperand ?? value)
            lastOperand = operand
            let result = apply(pending, acc, operand)
            if isError { return }
            value = result
            accumulator = result
            entry = nil
            justEvaluated = true
            hasOperandSinceOperator = false
        case .setRadix(let r):
            radix = r
            entry = nil
        case .setWidth(let w):
            applyWidth(w)
        case .toggleSigned:
            applySigned(!isSigned)
        case .toggleBit(let index):
            value = value.toggling(bit: index)
            entry = nil
            hasOperandSinceOperator = true
        case .recall(let v):
            value = v.with(width: width).with(isSigned: isSigned)
            entry = nil
            hasOperandSinceOperator = true
        }
    }

    private var maxEntryDigits: Int {
        switch radix {
        case .binary: width.rawValue
        case .octal: (width.rawValue + 2) / 3
        case .decimal: 20
        case .hexadecimal: width.rawValue / 4
        }
    }

    private mutating func allClear() {
        value = ProgrammerValue(bits: 0, width: width, isSigned: isSigned)
        entry = nil
        accumulator = nil
        pendingOperator = nil
        lastOperand = nil
        justEvaluated = false
        hasOperandSinceOperator = false
        isError = false
    }

    private mutating func applyWidth(_ w: BitWidth) {
        width = w
        value = value.with(width: w)
        accumulator = accumulator?.with(width: w)
        entry = nil
    }

    private mutating func applySigned(_ signed: Bool) {
        isSigned = signed
        value = value.with(isSigned: signed)
        accumulator = accumulator?.with(isSigned: signed)
        entry = nil
    }

    private mutating func apply(_ op: ProgrammerOperator, _ a: ProgrammerValue, _ b: ProgrammerValue) -> ProgrammerValue {
        do {
            switch op {
            case .and: return a & b
            case .or: return a | b
            case .xor: return a ^ b
            case .nor: return a.nor(b)
            case .add: return a.adding(b)
            case .subtract: return a.subtracting(b)
            case .multiply: return a.multiplied(by: b)
            case .divide: return try a.divided(by: b)
            case .modulo: return try a.remainder(dividingBy: b)
            case .shiftLeft: return a.shiftedLeft(by: Int(truncatingIfNeeded: b.unsignedValue))
            case .shiftRight: return a.shiftedRight(by: Int(truncatingIfNeeded: b.unsignedValue))
            }
        } catch {
            isError = true
            return a
        }
    }

    private func applyUnary(_ op: ProgrammerUnary, _ v: ProgrammerValue) -> ProgrammerValue {
        switch op {
        case .not: ~v
        case .negate: v.negated
        case .rotateLeft: v.rotatedLeft()
        case .rotateRight: v.rotatedRight()
        case .shiftLeftOne: v.shiftedLeft(by: 1)
        case .shiftRightOne: v.shiftedRight(by: 1)
        case .onesComplement: v.onesComplement
        case .twosComplement: v.twosComplement
        case .byteFlip: v.byteSwapped
        case .wordFlip: v.wordSwapped
        }
    }

    // MARK: Display

    /// Main line in the current radix (grouped), or `Error`.
    public var primaryText: String {
        if isError { return "Error" }
        if let entry { return groupEntry(entry) }
        return value.groupedText(radix: radix, separator: radix == .decimal ? "," : " ")
    }

    private func groupEntry(_ entry: String) -> String {
        let negative = entry.hasPrefix("-")
        let digits = negative ? String(entry.dropFirst()) : entry
        var out = ""
        let count = digits.count
        for (index, ch) in digits.enumerated() {
            if index > 0, (count - index) % radix.groupSize == 0 { out += radix == .decimal ? "," : " " }
            out.append(ch)
        }
        return (negative ? "-" : "") + out
    }

    /// The same value in every base, for the secondary rows of the programmer display.
    public var conversions: [(radix: Radix, text: String)] {
        Radix.allCases.map { ($0, value.groupedText(radix: $0, separator: $0 == .decimal ? "," : " ")) }
    }
}
