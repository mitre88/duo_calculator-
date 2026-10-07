/// A machine integer: raw bits interpreted at a given width and signedness, with hardware wrap-around.
public struct ProgrammerValue: Sendable, Hashable, Codable {
    public private(set) var bits: UInt64
    public var width: BitWidth {
        didSet { bits &= width.mask }
    }
    public var isSigned: Bool

    public init(bits: UInt64 = 0, width: BitWidth = .sixtyFour, isSigned: Bool = true) {
        self.width = width
        self.isSigned = isSigned
        self.bits = bits & width.mask
    }

    public init(_ value: Int64, width: BitWidth = .sixtyFour, isSigned: Bool = true) {
        self.init(bits: UInt64(bitPattern: value), width: width, isSigned: isSigned)
    }

    public static let zero = ProgrammerValue()

    // MARK: Interpretation

    public var unsignedValue: UInt64 { bits }

    /// Sign-extended value when `isSigned`, otherwise the unsigned magnitude as `Int64` (may overflow to negative for 64-bit).
    public var signedValue: Int64 {
        if width == .sixtyFour { return Int64(bitPattern: bits) }
        if bits & width.signBit != 0 {
            return Int64(bitPattern: bits | ~width.mask)
        }
        return Int64(bits)
    }

    public var isNegative: Bool { isSigned && (bits & width.signBit) != 0 }

    public var isZero: Bool { bits == 0 }

    /// Decimal value as an exact `CalcValue` (for hand-off to the scientific calculator).
    public var calcValue: CalcValue {
        if isSigned { return CalcValue(Int(signedValue)) }
        if bits <= UInt64(Int.max) { return CalcValue(Int(bits)) }
        return CalcValue(literal: String(bits)) ?? .zero
    }

    public func bit(at index: Int) -> Bool {
        guard index >= 0, index < width.rawValue else { return false }
        return (bits >> UInt64(index)) & 1 == 1
    }

    /// All bits, least significant first, `width` entries.
    public var bitArray: [Bool] { (0..<width.rawValue).map { bit(at: $0) } }

    public func toggling(bit index: Int) -> ProgrammerValue {
        guard index >= 0, index < width.rawValue else { return self }
        return with(bits: bits ^ (UInt64(1) << UInt64(index)))
    }

    public func with(bits newBits: UInt64) -> ProgrammerValue {
        ProgrammerValue(bits: newBits, width: width, isSigned: isSigned)
    }

    public func with(width newWidth: BitWidth) -> ProgrammerValue {
        // Narrowing truncates; widening sign-extends signed values (like a C cast).
        if isSigned, newWidth.rawValue > width.rawValue {
            return ProgrammerValue(bits: UInt64(bitPattern: signedValue), width: newWidth, isSigned: isSigned)
        }
        return ProgrammerValue(bits: bits, width: newWidth, isSigned: isSigned)
    }

    public func with(isSigned signed: Bool) -> ProgrammerValue {
        ProgrammerValue(bits: bits, width: width, isSigned: signed)
    }

    // MARK: Text

    /// Digits in `radix`: two's-complement bit pattern for binary/octal/hex, signed decimal when `isSigned`.
    public func text(radix: Radix) -> String {
        switch radix {
        case .decimal:
            return isSigned ? String(signedValue) : String(bits)
        default:
            return String(bits, radix: radix.rawValue, uppercase: true)
        }
    }

    /// Grouped text (`FF FF`, `1111 0000`, `1,234`).
    public func groupedText(radix: Radix, separator: String = " ") -> String {
        let raw = text(radix: radix)
        let negative = raw.hasPrefix("-")
        let digits = negative ? String(raw.dropFirst()) : raw
        var out = ""
        let count = digits.count
        for (index, ch) in digits.enumerated() {
            if index > 0, (count - index) % radix.groupSize == 0 { out += separator }
            out.append(ch)
        }
        return (negative ? "-" : "") + out
    }

    /// Parses digits typed in `radix` (optional leading `-` for signed decimal). Returns `nil` when invalid.
    public static func parse(_ text: String, radix: Radix, width: BitWidth, isSigned: Bool) -> ProgrammerValue? {
        var body = text.uppercased()
        var negative = false
        if body.hasPrefix("-") { negative = true; body.removeFirst() }
        guard !body.isEmpty, body.allSatisfy({ radix.validDigits.contains($0) }) else { return nil }
        guard let magnitude = UInt64(body, radix: radix.rawValue) else { return nil }
        let bits = negative ? (~magnitude &+ 1) : magnitude
        return ProgrammerValue(bits: bits, width: width, isSigned: isSigned)
    }

    /// ASCII / Unicode scalar for the low bits, when printable.
    public var characterDescription: String? {
        guard bits <= 0x10FFFF, let scalar = Unicode.Scalar(UInt32(bits)) else { return nil }
        let character = Character(scalar)
        if scalar.value < 0x20 || scalar.value == 0x7F { return nil }
        return String(character)
    }

    // MARK: Bitwise

    public static func & (a: ProgrammerValue, b: ProgrammerValue) -> ProgrammerValue { a.with(bits: a.bits & b.bits) }
    public static func | (a: ProgrammerValue, b: ProgrammerValue) -> ProgrammerValue { a.with(bits: a.bits | b.bits) }
    public static func ^ (a: ProgrammerValue, b: ProgrammerValue) -> ProgrammerValue { a.with(bits: a.bits ^ b.bits) }
    public static prefix func ~ (a: ProgrammerValue) -> ProgrammerValue { a.with(bits: ~a.bits) }

    public func nor(_ other: ProgrammerValue) -> ProgrammerValue { ~(self | other) }

    public func shiftedLeft(by n: Int) -> ProgrammerValue {
        guard n > 0 else { return n == 0 ? self : shiftedRight(by: -n) }
        return with(bits: n >= 64 ? 0 : bits << UInt64(n))
    }

    /// Logical shift for unsigned values, arithmetic (sign-propagating) for signed ones.
    public func shiftedRight(by n: Int) -> ProgrammerValue {
        guard n > 0 else { return n == 0 ? self : shiftedLeft(by: -n) }
        if isSigned {
            let shifted = n >= 64 ? (signedValue < 0 ? -1 : 0) : signedValue >> Int64(n)
            return with(bits: UInt64(bitPattern: shifted))
        }
        return with(bits: n >= 64 ? 0 : bits >> UInt64(n))
    }

    public func rotatedLeft(by n: Int = 1) -> ProgrammerValue {
        let w = width.rawValue
        let k = ((n % w) + w) % w
        if k == 0 { return self }
        let left = (bits << UInt64(k)) & width.mask
        let right = bits >> UInt64(w - k)
        return with(bits: left | right)
    }

    public func rotatedRight(by n: Int = 1) -> ProgrammerValue { rotatedLeft(by: -n) }

    public var onesComplement: ProgrammerValue { ~self }

    public var twosComplement: ProgrammerValue { with(bits: ~bits &+ 1) }

    /// Reverses the order of the bytes within the word.
    public var byteSwapped: ProgrammerValue {
        let byteCount = width.rawValue / 8
        var result: UInt64 = 0
        for i in 0..<byteCount {
            let byte = (bits >> UInt64(8 * i)) & 0xFF
            result |= byte << UInt64(8 * (byteCount - 1 - i))
        }
        return with(bits: result)
    }

    /// Swaps 16-bit words (no-op below 32 bits).
    public var wordSwapped: ProgrammerValue {
        let wordCount = width.rawValue / 16
        guard wordCount > 1 else { return self }
        var result: UInt64 = 0
        for i in 0..<wordCount {
            let word = (bits >> UInt64(16 * i)) & 0xFFFF
            result |= word << UInt64(16 * (wordCount - 1 - i))
        }
        return with(bits: result)
    }

    // MARK: Arithmetic (wrap-around)

    public func adding(_ other: ProgrammerValue) -> ProgrammerValue { with(bits: bits &+ other.bits) }
    public func subtracting(_ other: ProgrammerValue) -> ProgrammerValue { with(bits: bits &- other.bits) }
    public func multiplied(by other: ProgrammerValue) -> ProgrammerValue { with(bits: bits &* other.bits) }

    public func divided(by other: ProgrammerValue) throws -> ProgrammerValue {
        guard !other.isZero else { throw CalcError.divisionByZero }
        if isSigned {
            let (q, overflow) = signedValue.dividedReportingOverflow(by: other.signedValue)
            return with(bits: UInt64(bitPattern: overflow ? signedValue : q))
        }
        return with(bits: bits / other.bits)
    }

    public func remainder(dividingBy other: ProgrammerValue) throws -> ProgrammerValue {
        guard !other.isZero else { throw CalcError.divisionByZero }
        if isSigned {
            let (r, overflow) = signedValue.remainderReportingOverflow(dividingBy: other.signedValue)
            return with(bits: UInt64(bitPattern: overflow ? 0 : r))
        }
        return with(bits: bits % other.bits)
    }

    public var negated: ProgrammerValue { twosComplement }
}
