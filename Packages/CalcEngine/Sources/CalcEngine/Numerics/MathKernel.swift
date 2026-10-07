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
        let x = a.approx, y = b.approx
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
            if let xf = x.exactFraction, abs(n) <= CalcPrecision.maxIntegerPowerExponent {
                return CalcValue(exact: fractionPower(xf, n))
            }
            let xm = x.approx
            let estimate = Double(n) * log10Estimate(xm.abs)
            if estimate > overflowLimit { throw CalcError.overflow }
            if estimate < -overflowLimit { return .zero }
            if abs(n) <= CalcPrecision.maxIntegerPowerExponent {
                return try settle(xm.pow(n, working))
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
        let t = y.multiply(BigDecimal.log(x, rounding), rounding)
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
            if let exponent = x.decimalExponent, abs(exponent) > CalcPrecision.maxDoubleSeedExponent {
                // BigDecimal.root seeds Newton with a Double, which under/overflows beyond ~1e±308.
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
        let xm = x.approx
        switch fn {
        case .ln: return try settle(BigDecimal.log(xm, working))
        case .log10: return try settle(BigDecimal.log10(xm, working))
        default: return try settle(BigDecimal.log2(xm, working))
        }
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
                reduced = CalcValue(approx: x.approx.quotientAndRemainder(BigDecimal(360)).remainder)
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
        default: r = BigDecimal.atan(x.approx, g)
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
        let g = guardRounding()
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
