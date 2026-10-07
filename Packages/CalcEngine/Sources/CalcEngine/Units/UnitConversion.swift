/// Exact unit conversion through the category's base unit.
public enum UnitConverter {
    /// `x[from]` → `[to]`. Throws when the units belong to different categories.
    public static func convert(_ value: CalcValue, from: UnitDefinition, to: UnitDefinition) throws -> CalcValue {
        guard from.category == to.category else { throw CalcError.domain }
        if from == to { return value }
        // base = x · f_from + k_from ;  result = (base − k_to) / f_to
        let base = try MathKernel.add(MathKernel.multiply(value, from.factor.value), from.offset.value)
        let shifted = try MathKernel.subtract(base, to.offset.value)
        return try MathKernel.divide(shifted, to.factor.value)
    }

    /// Converts into every unit of the same category (for the "all units" list).
    public static func table(_ value: CalcValue, from: UnitDefinition) -> [(unit: UnitDefinition, value: CalcValue?)] {
        UnitCatalog.units(in: from.category).map { ($0, try? convert(value, from: from, to: $0)) }
    }
}
