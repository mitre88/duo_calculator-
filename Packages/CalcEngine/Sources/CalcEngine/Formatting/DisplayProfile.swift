/// How many digits the display can show. Chosen by the layout (compact width → `.compact`).
public enum DisplayProfile: String, Sendable, Codable, Hashable, CaseIterable {
    case regular
    case compact

    public var significantDigits: Int {
        self == .regular ? CalcPrecision.displayRegular : CalcPrecision.displayCompact
    }

    /// Decimal exponents inside this range are shown in plain notation; outside it, `1.5e16` style.
    public var plainExponentRange: ClosedRange<Int> { -6...(significantDigits - 1) }
}
