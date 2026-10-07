import BigDecimal

/// Precision policy of the engine (the "guard digits" model).
///
/// ```
/// compute  P_work = 60 significant digits (BigDecimal, round half even)
/// display  P_disp = 16 (regular) / 12 (compact), round half away from zero
/// ```
/// Values are never re-rounded between operations; only the display rounds.
public enum CalcPrecision {
    /// Working precision of every approximate (BigDecimal) operation.
    public static let working = 60
    /// Digits used by `CalcValue.canonicalString()` when comparing against the Python oracle.
    public static let canonical = 30
    /// Significant digits shown on a regular-width display.
    public static let displayRegular = 16
    /// Significant digits shown on a compact-width display.
    public static let displayCompact = 12
    /// Extra digits used *inside* transcendental evaluations before rounding back to `working`.
    public static let transcendentalGuardDigits = 30
    /// `a ± b` snaps to exact zero when `|r| < 10^-(working - guard) · max(|a|, |b|)`.
    public static let cancellationGuardDigits = 5
    /// Transcendental results with `|r| < 10^zeroSnapExponent` snap to zero…
    public static let zeroSnapExponent = -40
    /// …as long as the argument was not itself tiny (`|arg| ≥ 10^zeroSnapArgumentExponent`).
    public static let zeroSnapArgumentExponent = -20
    /// Largest `n` for which `n!` is computed exactly.
    public static let maxExactFactorial = 20_000
    /// Largest non-integer `x` for which `x! = Γ(x+1)` is computed.
    public static let maxGammaArgument = 10_000
    /// Integer exponents up to this magnitude are computed exactly / by exact power; beyond it `exp(y·ln x)` is used.
    public static let maxIntegerPowerExponent = 4_096
    /// Decimal exponent above which a result is reported as overflow.
    public static let overflowDecimalExponent = 1_000_000
    /// Exact fractions whose numerator + denominator exceed this many bits are demoted to the approx lane.
    public static let maxExactBits = 1_024
    /// Maximum number of digits accepted while typing a number.
    public static let maxEntryDigits = 16
    /// Radian arguments above 10^300 are refused: reducing them modulo 2π would need more than 360 digits of π.
    public static let maxTrigArgumentExponent = 300
    /// Beyond 10^±300 BigDecimal's Newton seeds (`Double`) under/overflow; use exp(log) instead.
    public static let maxDoubleSeedExponent = 300
    /// |x| ≥ 70 → tanh x = ±1 at 60 digits (1 − tanh 70 ≈ 3·10^−61); avoids evaluating e^x for huge x.
    public static let tanhSaturationArgument = 70
    /// From |x| ≥ 20 the hyperbolic functions are evaluated through exp instead of BigDecimal's Taylor series.
    public static let hyperbolicSeriesLimit = 20
    /// Exact integer powers are computed only while `(bits of numerator + denominator) × |n|` stays below this;
    /// anything larger would be demoted to the approx lane anyway (1 024 bits) after a very expensive BInt power.
    public static let maxExactPowerBits = 8_192
    /// Approx integer powers / roots up to this exponent use BigDecimal's direct BInt power; beyond, exp(log).
    public static let maxDirectPowerExponent = 64

    /// Rounding context for the working precision (`Rounding` is not `Sendable`, so it is built on demand).
    public static var workingRounding: Rounding { Rounding(.toNearestOrEven, working) }

    /// Working precision plus `extra` guard digits.
    public static func rounding(extra: Int) -> Rounding { Rounding(.toNearestOrEven, working + max(0, extra)) }

    /// Arbitrary precision context.
    public static func rounding(digits: Int, mode: RoundingRule = .toNearestOrEven) -> Rounding {
        Rounding(mode, max(1, digits))
    }
}
