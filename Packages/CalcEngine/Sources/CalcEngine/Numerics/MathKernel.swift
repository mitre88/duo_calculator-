import Foundation
import BigInt
import BigDecimal

/// Every numeric operation of the engine. This is the **only** file that calls BigDecimal's
/// transcendental functions, and it validates domains *before* calling them (several of them
/// use `precondition` and would crash on invalid input).
///
/// Thread-safety: BigDecimal keeps global caches (π, factorials, Spouge constants), so callers
/// must serialize access. The app funnels every evaluation through one actor; the tests run
/// `.serialized`.
public enum MathKernel {

    // MARK: - Rounding helpers

    static var working: Rounding { CalcPrecision.workingRounding }

    /// BigDecimal's series lose up to ~25 digits on some inputs (tanh(50), cos near 360°), so transcendental
    /// calls run with 30 guard digits and are rounded back to the working precision.
    static func guardRounding(_ extra: Int = CalcPrecision.transcendentalGuardDigits) -> Rounding { CalcPrecision.rounding(extra: extra) }

    /// Rounds to working precision and rejects NaN/∞/overflow.
    static func settle(_ d: BigDecimal) throws -> CalcValue {
        if d.isZero { return .zero }   // exact zero: `0!`, `x^0`, integer tests all see a real zero
        return try checkOverflow(CalcValue(approx: d))
    }

    // MARK: - Overflow

    public static func checkOverflow(_ v: CalcValue) throws -> CalcValue {
        guard case .approx(let d) = v.storage else { return v }
        if d.isNaN || d.isInfinite { throw CalcError.overflow }
        if !d.isZero, d.precision + d.exponent - 1 > CalcPrecision.overflowDecimalExponent {
            throw CalcError.overflow
        }
        return v
    }

    /// Rough `log10(|x|)` as a `Double` — used only for overflow estimates.
    static func log10Estimate(_ d: BigDecimal) -> Double {
        if d.isZero { return -Double.infinity }
        if d.isNaN { return .nan }
        if d.isInfinite { return .infinity }
        let exponent = d.precision + d.exponent - 1
        let digits = d.digits.abs.asString()
        let lead = String(digits.prefix(15))
        let mantissa = (Double(lead) ?? 1) / pow(10.0, Double(lead.count - 1))
        return Double(exponent) + log10(mantissa)
    }

    static var overflowLimit: Double { Double(CalcPrecision.overflowDecimalExponent) }

    // MARK: - Constants

    public static func pi() -> CalcValue { CalcValue(approx: BigDecimal.pi(working)) }

    public static func e() -> CalcValue { CalcValue(approx: BigDecimal.exp(BigDecimal.one, working)) }

    // MARK: - Arithmetic

    public static func add(_ a: CalcValue, _ b: CalcValue) throws -> CalcValue {
        try addSigned(a, b, subtracting: false)
    }

    public static func subtract(_ a: CalcValue, _ b: CalcValue) throws -> CalcValue {
        try addSigned(a, b, subtracting: true)
    }

    static func addSigned(_ a: CalcValue, _ b: CalcValue, subtracting: Bool) throws -> CalcValue {
        if let x = a.exactFraction, let y = b.exactFraction {
            return CalcValue(exact: subtracting ? x - y : x + y)
        }
        if b.isZero { return try checkOverflow(a) }
        if a.isZero { return try checkOverflow(subtracting ? b.negated : b) }
        let x = a.approx, y = b.approx
        // Operands whose magnitudes differ by more than the working precision do not interact at all:
        // skip BigDecimal's exponent alignment (a 10^999999-digit integer for `1e999999 + 1`) and keep
        // the dominant operand.
        if let ex = a.decimalExponent, let ey = b.decimalExponent,
           abs(ex - ey) > CalcPrecision.working + CalcPrecision.transcendentalGuardDigits {
            return try checkOverflow(ex > ey ? CalcValue(approx: x) : CalcValue(approx: subtracting ? -y : y))
        }
        let r = subtracting ? x.subtract(y, working) : x.add(y, working)
        return try checkOverflow(cancellationSnap(r, x, y))
    }

    /// `a ± b` that lands below `10^-(working-guard)` relative to its operands is pure rounding noise.
    static func cancellationSnap(_ r: BigDecimal, _ x: BigDecimal, _ y: BigDecimal) -> CalcValue {
        if r.isZero { return .zero }
        let scale = BigDecimal.maximum(x.abs, y.abs)
        let epsilon = BigDecimal(1, -(CalcPrecision.working - CalcPrecision.cancellationGuardDigits))
        if r.abs < scale.multiply(epsilon, working) { return .zero }
        return CalcValue(approx: r)
    }

    public static func multiply(_ a: CalcValue, _ b: CalcValue) throws -> CalcValue {
        if let x = a.exactFraction, let y = b.exactFraction { return CalcValue(exact: x * y) }
        if a.isZero || b.isZero { return .zero }
        return try settle(a.approx.multiply(b.approx, working))
    }

    public static func divide(_ a: CalcValue, _ b: CalcValue) throws -> CalcValue {
        if b.isZero { throw CalcError.divisionByZero }
        if let x = a.exactFraction, let y = b.exactFraction { return CalcValue(exact: x / y) }
        if a.isZero { return .zero }
        return try settle(a.approx.divide(b.approx, working))
    }

    public static func negate(_ a: CalcValue) -> CalcValue { a.negated }

    /// `x %` → `x / 100`
    public static func percent(_ a: CalcValue) -> CalcValue {
        if let x = a.exactFraction { return CalcValue(exact: x / 100) }
        return CalcValue(approx: a.approx.divide(100, working))
    }

    // MARK: - Powers and roots

    public static func power(_ x: CalcValue, _ y: CalcValue) throws -> CalcValue {
        if x.isZero {
            if y.isZero { return .one }
            if y.isNegative { throw CalcError.divisionByZero }
            return .zero
        }
        if y.isZero { return .one }
        if let yf = y.exactFraction, yf.isInteger {
            guard let n = yf.numerator.asInt() else { return try hugeIntegerPower(x, exponent: yf.numerator) }
            if let xf = x.exactFraction, abs(n) <= CalcPrecision.maxIntegerPowerExponent,
               (xf.numerator.bitWidth + xf.denominator.bitWidth) * abs(n) <= CalcPrecision.maxExactPowerBits {
                return CalcValue(exact: fractionPower(xf, n))
            }
            let xm = x.approx
            let estimate = Double(n) * log10Estimate(xm.abs)
            if estimate > overflowLimit { throw CalcError.overflow }
            if estimate < -overflowLimit { return .zero }
            if abs(n) <= CalcPrecision.maxDirectPowerExponent {
                return try settle(xm.pow(n, working))   // exact BInt power of the mantissa, then rounded
            }
            let magnitude = try expOfLog(xm.abs, BigDecimal(n))
            let negative = xm.isNegative && (n & 1 == 1)
            return try settle(negative ? -magnitude : magnitude)
        }
        // Non-integer exponent.
        if x.isNegative { throw CalcError.domain }
        if let xf = x.exactFraction, let yf = y.exactFraction,
           let q = yf.denominator.asInt(), q <= 64,
           let p = yf.numerator.asInt(), abs(p) <= CalcPrecision.maxIntegerPowerExponent,
           let r = exactRoot(xf, q) {
            return CalcValue(exact: fractionPower(r, p))
        }
        let xm = x.approx, ym = y.approx
        let estimate = ym.asDouble() * log10Estimate(xm)
        if estimate > overflowLimit { throw CalcError.overflow }
        if estimate < -overflowLimit { return .zero }
        return try settle(expOfLog(xm, ym))
    }

    /// Integer exponents beyond `Int` — only the magnitude of the base decides the outcome.
    static func hugeIntegerPower(_ x: CalcValue, exponent n: BInt) throws -> CalcValue {
        let magnitude = x.magnitude
        if magnitude == .one {
            return (x.isNegative && n.isOdd) ? CalcValue(-1) : .one
        }
        let growing = magnitude > .one
        if growing == !n.isNegative { throw CalcError.overflow }
        return .zero
    }

    /// `exp(y · ln x)` for `x > 0`, with enough guard digits for large `|y · ln x|`.
    static func expOfLog(_ x: BigDecimal, _ y: BigDecimal) throws -> BigDecimal {
        if x == BigDecimal.one || y.isZero { return BigDecimal.one }
        let yExponent = y.isZero ? 0 : (y.precision + y.exponent - 1)
        let rounding = guardRounding(17 + max(0, yExponent + 1))
        let t = y.multiply(naturalLog(x, rounding), rounding)
        if t.isZero { return BigDecimal.one }
        let estimate = t.asDouble() / log(10.0)
        if estimate > overflowLimit { throw CalcError.overflow }
        if estimate < -overflowLimit { return BigDecimal.zero }
        return BigDecimal.exp(t, working)
    }

    /// Exact `k`-th root of a non-negative fraction when numerator and denominator are perfect powers.
    static func exactRoot(_ f: BFraction, _ k: Int) -> BFraction? {
        guard k >= 1, !f.isNegative else { return nil }
        if k == 1 { return f }
        let (rootN, remainderN) = f.numerator.rootRemainder(k)
        guard remainderN.isZero else { return nil }
        let (rootD, remainderD) = f.denominator.rootRemainder(k)
        guard remainderD.isZero else { return nil }
        return BFraction(rootN, rootD)
    }

    /// `n`-th root of `x` (the `ʸ√x` key, `y = n`). Odd roots of negative numbers are allowed.
    public static func root(_ x: CalcValue, _ n: CalcValue) throws -> CalcValue {
        if n.isZero || n.isNegative { throw CalcError.domain }
        if let nf = n.exactFraction, nf.isInteger, let k = nf.numerator.asInt() {
            if x.isNegative {
                if k % 2 == 0 { throw CalcError.domain }
                return try root(x.negated, n).negated
            }
            if x.isZero { return .zero }
            if let xf = x.exactFraction, k <= 64, let r = exactRoot(xf, k) {
                return CalcValue(exact: r)
            }
            if k > CalcPrecision.maxDirectPowerExponent || abs(x.decimalExponent ?? 0) > CalcPrecision.maxDoubleSeedExponent {
                // BigDecimal.root seeds Newton with a Double (under/overflows beyond ~1e±308) and raises to
                // the (k−1)-th power on every iteration; exp(log) is accurate and cheap for any k.
                return try settle(expOfLog(x.approx, BigDecimal.one.divide(BigDecimal(k), guardRounding())))
            }
            return try settle(BigDecimal.root(x.approx, BigDecimal(k), working))
        }
        if x.isNegative { throw CalcError.domain }
        if x.isZero { return .zero }
        let g = guardRounding()
        return try settle(expOfLog(x.approx, BigDecimal.one.divide(n.approx, g)))
    }

    // MARK: - Factorial

    public static func factorial(_ x: CalcValue) throws -> CalcValue {
        if x.isNegative { throw CalcError.domain }
        if x.isInteger {
            guard let n = x.asInt, n <= CalcPrecision.maxExactFactorial else { throw CalcError.overflow }
            return CalcValue(BInt.factorial(n))
        }
        if x.approx > BigDecimal(CalcPrecision.maxGammaArgument) { throw CalcError.overflow }
        return try settle(BigDecimal.factorial(x.approx, working))
    }

    // MARK: - Unary functions

    public static func apply(_ fn: UnaryFunction, to x: CalcValue, angle: AngleMode) throws -> CalcValue {
        switch fn {
        case .square: return try power(x, CalcValue(2))
        case .cube: return try power(x, CalcValue(3))
        case .reciprocal: return try divide(.one, x)
        case .sqrt: return try root(x, CalcValue(2))
        case .cbrt: return try root(x, CalcValue(3))
        case .pow10: return try power(CalcValue(10), x)
        case .pow2: return try power(CalcValue(2), x)
        case .abs: return x.magnitude
        case .exp: return try exponential(x)
        case .ln, .log10, .log2: return try logarithm(fn, x)
        case .sin, .cos, .tan: return try trig(fn, x, angle: angle)
        case .asin, .acos, .atan: return try inverseTrig(fn, x, angle: angle)
        case .sinh, .cosh, .tanh, .asinh, .acosh, .atanh: return try hyperbolic(fn, x)
        }
    }

    static func exponential(_ x: CalcValue) throws -> CalcValue {
        if x.isZero { return .one }
        let xm = x.approx
        let estimate = xm.asDouble() / log(10.0)
        if estimate > overflowLimit { throw CalcError.overflow }
        if estimate < -overflowLimit { return .zero }
        return try settle(BigDecimal.exp(xm, working))
    }

    static func logarithm(_ fn: UnaryFunction, _ x: CalcValue) throws -> CalcValue {
        if x.isZero || x.isNegative { throw CalcError.domain }
        if let xf = x.exactFraction {
            if xf == 1 { return .zero }
            if fn == .log10, let k = exactLog(xf, base: 10) { return CalcValue(k) }
            if fn == .log2, let k = exactLog(xf, base: 2) { return CalcValue(k) }
        }
        let g = guardRounding()
        let ln = naturalLog(x.approx, g)
        switch fn {
        case .ln: return try settle(ln.round(working))
        case .log10: return try settle(ln.divide(BigDecimal.log(BigDecimal(10), g), g).round(working))
        default: return try settle(ln.divide(BigDecimal.log(BigDecimal(2), g), g).round(working))
        }
    }

    /// `ln x` for `x > 0` of any magnitude: `ln(m·10^e) = ln m + e·ln 10` with `m ∈ [1, 10)`, so the cost never
    /// depends on the exponent (BigDecimal's own `log` walks powers of 2 and 3 for `x < 10`, which is
    /// O(|e|) for `1e-999999`).
    static func naturalLog(_ x: BigDecimal, _ rounding: Rounding) -> BigDecimal {
        precondition(x.signum > 0)
        let e = x.precision + x.exponent - 1
        let mantissa = BigDecimal(x.significandBitPattern, -(x.precision - 1))   // 1 ≤ m < 10
        var result = mantissa == BigDecimal.one ? BigDecimal.zero : BigDecimal.log(mantissa, rounding)
        if e != 0 {
            result = result.add(BigDecimal(e).multiply(BigDecimal.log(BigDecimal(10), rounding), rounding), rounding)
        }
        return result
    }

    /// `k` such that `base^k == f` (k may be negative), or `nil`.
    static func exactLog(_ f: BFraction, base: Int) -> Int? {
        if f.numerator.isOne && !f.denominator.isOne {
            return exactLog(BFraction(f.denominator, BInt.ONE), base: base).map { -$0 }
        }
        guard f.denominator.isOne, f.numerator.isPositive else { return nil }
        var n = f.numerator
        var k = 0
        while !n.isOne {
            let (q, r) = n.quotientAndRemainder(dividingBy: base)
            if r != 0 { return nil }
            n = q
            k += 1
        }
        return k
    }

    /// `log_b(x)`
    public static func logBase(_ x: CalcValue, base b: CalcValue) throws -> CalcValue {
        if x.isZero || x.isNegative || b.isZero || b.isNegative || b == .one { throw CalcError.domain }
        if let xf = x.exactFraction, let bf = b.exactFraction {
            if xf == 1 { return .zero }
            if bf.isInteger, bf > 1, let base = bf.numerator.asInt(), let k = exactLog(xf, base: base) {
                return CalcValue(k)
            }
        }
        let g = guardRounding()
        let lb = BigDecimal.log(b.approx, g)
        if lb.isZero { throw CalcError.domain }
        return try settle(BigDecimal.log(x.approx, g).divide(lb, g))
    }

    // MARK: - Trigonometry

    static func zeroSnap(_ r: BigDecimal, argument: BigDecimal) throws -> CalcValue {
        if r.isZero { return .zero }
        if r.abs < BigDecimal(1, CalcPrecision.zeroSnapExponent),
           argument.abs >= BigDecimal(1, CalcPrecision.zeroSnapArgumentExponent) {
            return .zero
        }
        return try settle(r)
    }

    static func trig(_ fn: UnaryFunction, _ x: CalcValue, angle: AngleMode) throws -> CalcValue {
        let radians: BigDecimal
        var guardDigits = CalcPrecision.transcendentalGuardDigits
        switch angle {
        case .degrees:
            let reduced: CalcValue
            if let xf = x.exactFraction {
                // Reduce exactly modulo 360°, then consult the closed-form table.
                let turns = (xf / 360).floor()
                let r = xf - BFraction(turns * BInt(360), BInt.ONE)
                if r.isInteger, let d = r.numerator.asInt() {
                    let exact: BFraction?
                    switch fn {
                    case .sin: exact = ExactAngleTable.sine(degrees: d)
                    case .cos: exact = ExactAngleTable.cosine(degrees: d)
                    default: exact = try ExactAngleTable.tangent(degrees: d)
                    }
                    if let exact { return CalcValue(exact: exact) }
                }
                reduced = CalcValue(exact: r)
            } else {
                reduced = CalcValue(approx: reduceDegrees(x.approx))
            }
            let g = guardRounding()
            radians = reduced.approx(g).multiply(BigDecimal.pi(g), g).divide(BigDecimal(180), g)
        case .radians:
            if x.isZero { return fn == .cos ? .one : .zero }
            // Reducing modulo 2π costs one digit per integer digit of |x|: carry them as guard digits
            // (π is then computed to that precision) and refuse arguments beyond 10^300.
            let exponent = max(0, x.decimalExponent ?? 0)
            if exponent > CalcPrecision.maxTrigArgumentExponent { throw CalcError.domain }
            guardDigits += exponent
            radians = x.approx(CalcPrecision.rounding(extra: exponent))
        }
        let g = guardRounding(guardDigits)
        switch fn {
        case .sin:
            return try zeroSnap(BigDecimal.sin(radians, g).round(working), argument: radians)
        case .cos:
            return try zeroSnap(BigDecimal.cos(radians, g).round(working), argument: radians)
        default:
            // tan = sin / cos with the cosine snapped first: tan(π/2) is undefined, not 10^60-ish noise.
            let c = try zeroSnap(BigDecimal.cos(radians, g), argument: radians)
            if c.isZero { throw CalcError.domain }
            let s = BigDecimal.sin(radians, g)
            return try zeroSnap(s.divide(c.approx, g).round(working), argument: radians)
        }
    }

    /// `d mod 360` for an approx angle without aligning exponents. `m·10^e` with `e > 0` is an integer, so the
    /// remainder is `(m mod 360)·(10^e mod 360) mod 360` (10^e mod 360 is 280 for every e ≥ 3); smaller
    /// exponents keep BigDecimal's own remainder. Sign is preserved (sin(−θ) = −sin θ).
    static func reduceDegrees(_ d: BigDecimal) -> BigDecimal {
        guard d.exponent > 0 else { return d.quotientAndRemainder(BigDecimal(360)).remainder }
        let mantissa = d.significandBitPattern
        let base = (mantissa.abs % BInt(360)).asInt() ?? 0
        var power = 1, square = 10 % 360, k = d.exponent
        while k > 0 {
            if k & 1 == 1 { power = power * square % 360 }
            square = square * square % 360
            k >>= 1
        }
        let r = base * power % 360
        return BigDecimal(mantissa.isNegative ? -r : r)
    }

    static func inverseTrig(_ fn: UnaryFunction, _ x: CalcValue, angle: AngleMode) throws -> CalcValue {
        if fn != .atan, x.magnitude > .one { throw CalcError.domain }
        if let xf = x.exactFraction {
            let degrees: Int?
            switch fn {
            case .asin: degrees = ExactAngleTable.arcsineDegrees(xf)
            case .acos: degrees = ExactAngleTable.arccosineDegrees(xf)
            default: degrees = ExactAngleTable.arctangentDegrees(xf)
            }
            if let degrees {
                if angle == .degrees { return CalcValue(degrees) }
                if degrees == 0 { return .zero }
            }
        }
        let g = guardRounding()
        var r: BigDecimal
        switch fn {
        case .asin: r = BigDecimal.asin(x.approx, g)
        case .acos: r = BigDecimal.acos(x.approx, g)
        default:
            if let exponent = x.decimalExponent, exponent > CalcPrecision.asymptoticArgumentExponent {
                // atan x = ±(π/2 − 1/|x| + 1/(3|x|³) − …); the cubic term is below 10^−63 from |x| ≥ 10^21.
                let xm = x.approx
                let magnitude = BigDecimal.pi(g).divide(BigDecimal(2), g).subtract(BigDecimal.one.divide(xm.abs, g), g)
                r = xm.isNegative ? -magnitude : magnitude
            } else {
                r = BigDecimal.atan(x.approx, g)
            }
        }
        if angle == .degrees {
            r = r.multiply(BigDecimal(180), g).divide(BigDecimal.pi(g), g)
        }
        return try zeroSnap(r.round(working), argument: x.approx)
    }

    static func hyperbolic(_ fn: UnaryFunction, _ x: CalcValue) throws -> CalcValue {
        switch fn {
        case .acosh: if x < .one { throw CalcError.domain }
        case .atanh: if x.magnitude >= .one { throw CalcError.domain }
        default: break
        }
        if let xf = x.exactFraction {
            if xf.isZero { return fn == .cosh ? .one : .zero }
            if xf == 1 && fn == .acosh { return .zero }
        }
        let xm = x.approx
        if fn == .sinh || fn == .cosh {
            let estimate = xm.abs.asDouble() / log(10.0)
            if estimate > overflowLimit { throw CalcError.overflow }
        }
        if fn == .tanh, xm.abs >= BigDecimal(CalcPrecision.tanhSaturationArgument) {
            // 1 − tanh|x| < 2e^(−2|x|) < 10^−60 here: ±1 at working precision.
            return CalcValue(approx: xm.isNegative ? -BigDecimal.one : BigDecimal.one)
        }
        let g = guardRounding()
        if fn == .asinh || fn == .acosh, let exponent = x.decimalExponent, exponent > CalcPrecision.asymptoticArgumentExponent {
            // asinh x = ±(ln 2|x| + 1/(4x²) − …), acosh x = ln 2x − 1/(4x²) − …: the correction is below
            // 10^−60 from |x| ≥ 10^30, and ln of any magnitude is cheap through `naturalLog`.
            let magnitude = naturalLog(xm.abs.multiply(BigDecimal(2), g), g)
            return try settle(((fn == .asinh && xm.isNegative) ? -magnitude : magnitude).round(working))
        }
        if fn == .sinh || fn == .cosh || fn == .tanh, xm.abs >= BigDecimal(CalcPrecision.hyperbolicSeriesLimit) {
            // BigDecimal's sinh/cosh are Taylor series whose term count grows with |x| (sinh(2·10^6) would
            // never finish); its exp splits integral and fractional parts and is fast for any argument.
            let magnitude = xm.abs
            let e = BigDecimal.exp(magnitude, g)
            let inverse = BigDecimal.one.divide(e, g)
            let two = BigDecimal(2)
            let r: BigDecimal
            switch fn {
            case .sinh: r = (e - inverse).divide(two, g)
            case .cosh: r = (e + inverse).divide(two, g)
            default:    r = (e - inverse).divide(e + inverse, g)   // tanh = sinh / cosh
            }
            let signed = (fn != .cosh && xm.isNegative) ? -r : r
            return try settle(signed.round(working))
        }
        let r: BigDecimal
        switch fn {
        case .sinh: r = BigDecimal.sinh(xm, g)
        case .cosh: r = BigDecimal.cosh(xm, g)
        case .tanh: r = BigDecimal.tanh(xm, g)
        case .asinh: r = BigDecimal.asinh(xm, g)
        case .acosh: r = BigDecimal.acosh(xm, g)
        default: r = BigDecimal.atanh(xm, g)
        }
        return try zeroSnap(r.round(working), argument: xm)
    }
}
