import Foundation
import BigInt
import BigDecimal

// `BFraction` is a plain value type (two `BInt`s); it is safe to send across isolation domains.
extension BFraction: @retroactive @unchecked Sendable {}

/// A calculator number living in one of two lanes:
///
/// * `.exact` — a rational number (`BFraction`). Used for `+ − × ÷`, integer powers, percent,
///   literals, perfect roots and integer factorials. `1 ÷ 3 × 3 − 1 = 0` exactly.
/// * `.approx` — a `BigDecimal` rounded to `CalcPrecision.working` digits. Used for
///   transcendental functions or whenever an approx operand is involved.
///
/// Fractions that grow beyond `CalcPrecision.maxExactBits` are demoted to the approx lane.
public struct CalcValue: Sendable, Hashable, Comparable, CustomStringConvertible {
    public enum Storage: Sendable {
        case exact(BFraction)
        case approx(BigDecimal)
    }

    public private(set) var storage: Storage

    // MARK: Construction

    public init(exact fraction: BFraction) {
        if fraction.numerator.bitWidth + fraction.denominator.bitWidth > CalcPrecision.maxExactBits {
            storage = .approx(Self.decimal(from: fraction, CalcPrecision.workingRounding))
        } else {
            storage = .exact(fraction)
        }
    }

    public init(approx value: BigDecimal) {
        storage = .approx(value.round(CalcPrecision.workingRounding))
    }

    public init(_ integer: Int) {
        self.init(exact: BFraction(integer, 1))
    }

    public init(_ integer: BInt) {
        self.init(exact: BFraction(integer, BInt.ONE))
    }

    /// Exact value of a decimal literal such as `"1.5"`, `"2e3"`, `"-0.25"`, `".5"`.
    public init?(literal: String) {
        var text = literal.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix(".") { text = "0" + text }
        if text.hasPrefix("-.") { text = "-0" + text.dropFirst() }
        if text.hasSuffix(".") { text.removeLast() }
        guard !text.isEmpty, let fraction = BFraction(text) else { return nil }
        self.init(exact: fraction)
    }

    public static let zero = CalcValue(0)
    public static let one = CalcValue(1)

    // MARK: Lane queries

    public var isExact: Bool {
        if case .exact = storage { return true }
        return false
    }

    public var exactFraction: BFraction? {
        if case .exact(let f) = storage { return f }
        return nil
    }

    public var isZero: Bool {
        switch storage {
        case .exact(let f): f.isZero
        case .approx(let d): d.isZero
        }
    }

    public var isNegative: Bool {
        switch storage {
        case .exact(let f): f.isNegative
        case .approx(let d): d.isNegative
        }
    }

    public var signum: Int {
        switch storage {
        case .exact(let f): f.signum
        case .approx(let d): d.signum
        }
    }

    /// `true` when the value is an integer (exactly, or an integer-valued approximation).
    public var isInteger: Bool {
        switch storage {
        case .exact(let f): f.isInteger
        case .approx(let d): d.isFinite && BigDecimal.isIntValue(d)
        }
    }

    /// The value as `Int` when it is an integer that fits.
    public var asInt: Int? {
        switch storage {
        case .exact(let f): f.isInteger ? f.numerator.asInt() : nil
        case .approx(let d): (d.isFinite && BigDecimal.isIntValue(d)) ? d.asInt() : nil
        }
    }

    /// The value in the approx lane at working precision.
    public var approx: BigDecimal { approx(CalcPrecision.workingRounding) }

    public func approx(_ rounding: Rounding) -> BigDecimal {
        switch storage {
        case .exact(let f): Self.decimal(from: f, rounding)
        case .approx(let d): d
        }
    }

    /// `floor(log10 |x|)` — `nil` for zero.
    public var decimalExponent: Int? {
        if isZero { return nil }
        let d = approx(CalcPrecision.rounding(digits: 20))
        return d.precision + d.exponent - 1
    }

    public var negated: CalcValue {
        switch storage {
        case .exact(let f): CalcValue(exact: BFraction(-f.numerator, f.denominator))
        case .approx(let d): CalcValue(approx: -d)
        }
    }

    public var magnitude: CalcValue { isNegative ? negated : self }

    /// A 15-significant-digit `Double` approximation (for estimates, haptics, chart previews — never for results).
    public var doubleValue: Double {
        switch storage {
        case .exact(let f): f.asDouble()
        case .approx(let d): d.asDouble()
        }
    }

    // MARK: Conversions

    static func decimal(from fraction: BFraction, _ rounding: Rounding) -> BigDecimal {
        if fraction.denominator.isOne { return BigDecimal(fraction.numerator) }
        return BigDecimal(fraction.numerator).divide(BigDecimal(fraction.denominator), rounding)
    }

    static func fraction(from decimal: BigDecimal) -> BFraction? {
        guard decimal.isFinite else { return nil }
        if decimal.exponent >= 0 {
            return BFraction(decimal.digits * (BInt.TEN ** decimal.exponent), BInt.ONE)
        }
        return BFraction(decimal.digits, BInt.TEN ** (-decimal.exponent))
    }

    // MARK: Canonical text (shared with the Python oracle)

    /// Canonical scientific form `[-]d[.ddd]E[+|-]exp`, rounded to `digits` significant digits.
    /// Examples: `5E-1`, `1.23E+2`, `0E+0`, `-4.79425538604203E-1`.
    public func canonicalString(digits: Int = CalcPrecision.canonical,
                                mode: RoundingRule = .toNearestOrEven) -> String {
        let rounded: BigDecimal
        switch storage {
        case .exact(let f):
            rounded = Self.decimal(from: f, Rounding(mode, digits + 20)).round(Rounding(mode, digits))
        case .approx(let d):
            rounded = d.round(Rounding(mode, digits))
        }
        return Self.canonical(rounded)
    }

    public static func canonical(_ value: BigDecimal) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value.isNegative ? "-Infinity" : "Infinity" }
        if value.isZero { return "0E+0" }
        let t = value.trim
        var digits = t.digits.abs.asString()
        let sciExponent = digits.count - 1 + t.exponent
        let first = digits.removeFirst()
        var s = t.isNegative ? "-" : ""
        s.append(first)
        if !digits.isEmpty { s += "." + digits }
        s += "E" + (sciExponent >= 0 ? "+" : "-") + String(abs(sciExponent))
        return s
    }

    public var description: String { canonicalString() }

    // MARK: Hashable / Comparable

    public static func == (lhs: CalcValue, rhs: CalcValue) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case let (.exact(a), .exact(b)): a == b
        case let (.approx(a), .approx(b)): a == b
        default: false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch storage {
        case .exact(let f):
            hasher.combine(0)
            hasher.combine(f.numerator)
            hasher.combine(f.denominator)
        case .approx(let d):
            hasher.combine(1)
            hasher.combine(d)
        }
    }

    public static func < (lhs: CalcValue, rhs: CalcValue) -> Bool {
        if let a = lhs.exactFraction, let b = rhs.exactFraction { return a < b }
        return lhs.approx < rhs.approx
    }
}

// MARK: - Codable (text form: "exact:n/d" or "approx:<canonical 60 digits>")

extension CalcValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        if text.hasPrefix("exact:") {
            let body = text.dropFirst("exact:".count)
            let parts = body.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2, let n = BInt(parts[0]), let d = BInt(parts[1]), d.isNotZero else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad exact CalcValue: \(text)")
            }
            self.init(exact: BFraction(n, d))
        } else if text.hasPrefix("approx:") {
            let value = BigDecimal(String(text.dropFirst("approx:".count)))
            guard value.isFinite else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad approx CalcValue: \(text)")
            }
            self.init(approx: value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown CalcValue encoding: \(text)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch storage {
        case .exact(let f):
            try container.encode("exact:" + f.numerator.asString() + "/" + f.denominator.asString())
        case .approx(let d):
            try container.encode("approx:" + CalcValue.canonical(d))
        }
    }
}
