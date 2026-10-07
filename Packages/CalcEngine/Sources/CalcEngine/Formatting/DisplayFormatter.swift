import BigDecimal
import BigInt

/// Turns values and typed literals into display strings.
///
/// * results: rounded to the profile's significant digits (half away from zero), trailing zeros stripped,
///   grouped integer part, scientific notation (`1.2345e16`, `1e-7`) outside `plainExponentRange`;
/// * typed entries: echoed as typed (`1,234.50`, `2e-`), with live grouping.
public struct DisplayFormatter: Sendable, Hashable {
    public var profile: DisplayProfile
    public var separators: LocaleSeparators
    public var usesGrouping: Bool

    public init(profile: DisplayProfile = .regular, separators: LocaleSeparators = .enUS, usesGrouping: Bool = true) {
        self.profile = profile
        self.separators = separators
        self.usesGrouping = usesGrouping
    }

    public static let regularUS = DisplayFormatter()

    // MARK: Values

    public func format(_ value: CalcValue) -> String {
        format(value, significantDigits: profile.significantDigits)
    }

    public func format(_ value: CalcValue, significantDigits digits: Int) -> String {
        let rounded: BigDecimal
        switch value.storage {
        case .exact(let fraction):
            rounded = CalcValue.decimal(from: fraction, Rounding(.toNearestOrAwayFromZero, digits + 20))
                .round(Rounding(.toNearestOrAwayFromZero, digits))
        case .approx(let decimal):
            rounded = decimal.round(Rounding(.toNearestOrAwayFromZero, digits))
        }
        return format(decimal: rounded, significantDigits: digits)
    }

    func format(decimal value: BigDecimal, significantDigits digits: Int) -> String {
        if value.isNaN || value.isInfinite { return "Error" }
        if value.isZero { return "0" }
        let trimmed = value.trim
        let digitString = trimmed.digits.abs.asString()
        let exponent10 = digitString.count - 1 + trimmed.exponent
        let sign = trimmed.isNegative ? separators.minus : ""
        let plainRange = -6...(digits - 1)
        if plainRange.contains(exponent10) {
            return sign + plain(digits: digitString, exponent: trimmed.exponent)
        }
        var mantissa = String(digitString.prefix(1))
        let rest = digitString.dropFirst()
        if !rest.isEmpty { mantissa += separators.decimal + rest }
        let exponentText = (exponent10 < 0 ? separators.minus : "") + String(abs(exponent10))
        return sign + mantissa + separators.exponent + exponentText
    }

    private func plain(digits: String, exponent: Int) -> String {
        if exponent >= 0 {
            return group(digits + String(repeating: "0", count: exponent))
        }
        let pointPosition = digits.count + exponent
        if pointPosition > 0 {
            let integerPart = String(digits.prefix(pointPosition))
            let fractionPart = String(digits.dropFirst(pointPosition))
            return group(integerPart) + separators.decimal + fractionPart
        }
        return "0" + separators.decimal + String(repeating: "0", count: -pointPosition) + digits
    }

    /// Inserts grouping separators into a run of integer digits.
    public func group(_ integerDigits: String) -> String {
        guard usesGrouping, integerDigits.count > 3 else { return integerDigits }
        var out = ""
        let count = integerDigits.count
        for (index, character) in integerDigits.enumerated() {
            if index > 0, (count - index) % 3 == 0 { out += separators.grouping }
            out.append(character)
        }
        return out
    }

    // MARK: Typed entry

    /// Echo of a number being typed: `1,234.50`, `-0.`, `1.5e-3`.
    public func formatEntry(_ literal: NumberLiteral) -> String {
        if literal.isComputed, let value = literal.value { return format(value) }
        var integerPart = literal.mantissa
        var fractionPart: String?
        if let dot = integerPart.firstIndex(of: ".") {
            fractionPart = String(integerPart[integerPart.index(after: dot)...])
            integerPart = String(integerPart[..<dot])
        }
        if integerPart.isEmpty { integerPart = "0" }
        var text = (literal.isNegative ? separators.minus : "") + group(integerPart)
        if let fractionPart { text += separators.decimal + fractionPart }
        if let exponent = literal.exponent {
            let body = exponent.hasPrefix("-") ? separators.minus + exponent.dropFirst() : exponent
            text += separators.exponent + body
        }
        return text
    }
}
