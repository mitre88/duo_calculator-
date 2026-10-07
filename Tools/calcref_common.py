"""Shared helpers for the CalcEngine fixture generators.

Canonical number form used by every fixture (and mirrored by the Swift tests):

    [-]d[.ddd]E[+|-]exp      e.g.  "5E-1", "1.23E+2", "0E+0", "-4.79425538604203E-1"

* mantissa has no trailing zeros, exactly one digit before the point
* exponent always carries a sign
"""
from __future__ import annotations

from decimal import Decimal, ROUND_HALF_EVEN, ROUND_HALF_UP, localcontext
from fractions import Fraction

import mpmath
from mpmath import mp, mpf

WORKING_DIGITS = 60      # CalcPrecision.working   (BigDecimal Rounding precision)
CANON_DIGITS = 30        # digits used to compare Swift vs. Python approx results
DISPLAY_DIGITS = 16      # DisplayProfile.regular
DISPLAY_DIGITS_COMPACT = 12
CANCELLATION_GUARD = 5   # a ± b snaps to 0 below 10^-(WORKING-5) * max(|a|,|b|)
ZERO_SNAP_EXP = -40      # transcendental results below 1e-40 (with |arg| >= 1e-20) snap to 0
ZERO_SNAP_ARG_EXP = -20
MAX_EXACT_FACTORIAL = 20_000
MAX_GAMMA_ARG = 10_000
MAX_INT_POWER_EXP = 4_096
OVERFLOW_EXP = 1_000_000

mp.dps = WORKING_DIGITS + 10


class CalcError(Exception):
    """Mirror of CalcEngine.CalcError kinds."""

    def __init__(self, kind: str):
        super().__init__(kind)
        self.kind = kind   # divisionByZero | domain | overflow | syntax | tooComplex


# ----------------------------------------------------------------------------
# conversions
# ----------------------------------------------------------------------------

def fraction_to_decimal(fr: Fraction, prec: int = 80) -> Decimal:
    with localcontext() as ctx:
        ctx.prec = prec
        ctx.rounding = ROUND_HALF_EVEN
        return Decimal(fr.numerator) / Decimal(fr.denominator)


def mpf_to_decimal(x: mpf, digits: int = 65) -> Decimal:
    if x == 0:
        return Decimal(0)
    return Decimal(mpmath.nstr(x, digits, strip_zeros=False, min_fixed=0, max_fixed=0))


def value_to_decimal(v) -> Decimal:
    if isinstance(v, Fraction):
        return fraction_to_decimal(v)
    if isinstance(v, int):
        return Decimal(v)
    return mpf_to_decimal(v)


def round_sig(d: Decimal, digits: int, rounding=ROUND_HALF_EVEN) -> Decimal:
    if d == 0:
        return Decimal(0)
    with localcontext() as ctx:
        ctx.prec = digits
        ctx.rounding = rounding
        return +d


def canon_decimal(d: Decimal) -> str:
    """Canonical scientific string of a Decimal (see module doc)."""
    if d == 0:
        return "0E+0"
    sign, digits, exponent = d.as_tuple()
    ds = "".join(str(x) for x in digits).rstrip("0")
    stripped = len("".join(str(x) for x in digits)) - len(ds)
    exponent += stripped
    if not ds:
        return "0E+0"
    sci_exp = len(ds) - 1 + exponent
    mant = ds[0] + ("." + ds[1:] if len(ds) > 1 else "")
    return ("-" if sign else "") + mant + "E" + ("+" if sci_exp >= 0 else "-") + str(abs(sci_exp))


def canon(v, digits: int = CANON_DIGITS, rounding=ROUND_HALF_EVEN) -> str:
    return canon_decimal(round_sig(value_to_decimal(v), digits, rounding))


def canon_display(v, digits: int = DISPLAY_DIGITS) -> str:
    """Display rounding: half away from zero, like DisplayFormatter."""
    return canon(v, digits, ROUND_HALF_UP)


def literal_to_fraction(text: str) -> Fraction:
    """Exact rational value of a decimal literal such as '1.5e3' or '.25'."""
    return Fraction(Decimal(text))
