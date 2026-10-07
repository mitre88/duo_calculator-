/// Word size of the programmer calculator.
public enum BitWidth: Int, Sendable, Codable, Hashable, CaseIterable, Identifiable {
    case eight = 8
    case sixteen = 16
    case thirtyTwo = 32
    case sixtyFour = 64

    public var id: Int { rawValue }

    public var mask: UInt64 {
        self == .sixtyFour ? UInt64.max : (UInt64(1) << UInt64(rawValue)) - 1
    }

    public var signBit: UInt64 { UInt64(1) << UInt64(rawValue - 1) }

    public var label: String { "\(rawValue)-bit" }
}

/// Number base of the programmer calculator.
public enum Radix: Int, Sendable, Codable, Hashable, CaseIterable, Identifiable {
    case binary = 2
    case octal = 8
    case decimal = 10
    case hexadecimal = 16

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .binary: "BIN"
        case .octal: "OCT"
        case .decimal: "DEC"
        case .hexadecimal: "HEX"
        }
    }

    /// Digits that are valid in this base (`0…F`).
    public var validDigits: [Character] {
        Array("0123456789ABCDEF".prefix(rawValue))
    }

    /// Digit group size used when formatting (nibbles for binary, bytes for hex, thousands for decimal).
    public var groupSize: Int {
        switch self {
        case .binary: 4
        case .octal: 3
        case .decimal: 3
        case .hexadecimal: 2
        }
    }
}
