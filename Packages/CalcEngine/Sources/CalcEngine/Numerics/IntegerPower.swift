import BigInt

// BigInt and BigDecimal both declare `infix operator **`, which makes the operator ambiguous in any
// file that imports both modules. These helpers avoid the operator altogether.

/// `base^exponent` for a non-negative exponent (square-and-multiply).
func integerPower(_ base: BInt, _ exponent: Int) -> BInt {
    precondition(exponent >= 0, "negative exponent")
    var result = BInt.ONE
    var factor = base
    var e = exponent
    while e > 0 {
        if e & 1 == 1 { result *= factor }
        e >>= 1
        if e > 0 { factor *= factor }
    }
    return result
}

/// `10^exponent` for a non-negative exponent.
func powerOfTen(_ exponent: Int) -> BInt {
    integerPower(BInt.TEN, exponent)
}

/// `fraction^exponent` for any integer exponent (negative exponents invert; the caller guarantees a non-zero base).
func fractionPower(_ fraction: BFraction, _ exponent: Int) -> BFraction {
    if exponent == 0 { return BFraction.ONE }
    let magnitude = exponent.magnitude
    let numerator = integerPower(fraction.numerator, Int(magnitude))
    let denominator = integerPower(fraction.denominator, Int(magnitude))
    return exponent > 0 ? BFraction(numerator, denominator) : BFraction(denominator, numerator)
}
