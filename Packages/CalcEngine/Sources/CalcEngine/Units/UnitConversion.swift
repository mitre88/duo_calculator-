import BigInt

/// Exact unit conversion through the category's base unit.
public enum UnitConverter {
    /// `x[from]` → `[to]`. Throws when the units belong to different categories.
    public static func convert(_ value: CalcValue, from: UnitDefinition, to: UnitDefinition) throws -> CalcValue {
        guard from.category == to.category else { throw CalcError.domain }
        if from == to { return value }
        // result = x · (f_from / f_to) + (k_from − k_to) / f_to.  The rational parts and the π powers are
        // combined first, so conversions whose π cancels (degree → gradian, degree → arcminute) stay exact.
        let ratio = BFraction(from.factor.numerator, from.factor.denominator) / BFraction(to.factor.numerator, to.factor.denominator)
        var result = try MathKernel.multiply(value, CalcValue(exact: ratio))
        let piExponent = from.factor.piPower - to.factor.piPower
        if piExponent != 0 {
            result = try MathKernel.multiply(result, MathKernel.power(MathKernel.pi(), CalcValue(piExponent)))
        }
        if from.offset.numerator != 0 || to.offset.numerator != 0 {
            let offset = try MathKernel.divide(MathKernel.subtract(from.offset.value, to.offset.value), to.factor.value)
            result = try MathKernel.add(result, offset)
        }
        return result
    }

    /// Converts into every unit of the same category (for the "all units" list).
    public static func table(_ value: CalcValue, from: UnitDefinition) -> [(unit: UnitDefinition, value: CalcValue?)] {
        UnitCatalog.units(in: from.category).map { ($0, try? convert(value, from: from, to: $0)) }
    }
}
