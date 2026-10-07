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

    /// Rounding context for the working precision (`Rounding` is not `Sendable`, so it is built on demand).
    public static var workingRounding: Rounding { Rounding(.toNearestOrEven, working) }

    /// Working precision plus `extra` guard digits.
    public static func rounding(extra: Int) -> Rounding { Rounding(.toNearestOrEven, working + max(0, extra)) }

    /// Arbitrary precision context.
    public static func rounding(digits: Int, mode: RoundingRule = .toNearestOrEven) -> Rounding {
        Rounding(mode, max(1, digits))
    }
}
