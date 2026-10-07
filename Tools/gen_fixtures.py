#!/usr/bin/env python3
"""Generates transcendental.json — reference values computed with mpmath at 70 digits.

Each case:  {"id", "fn", "angle": "rad"|"deg"|null, "args": [...], "expected": canon60,
             "expected16": canon16 (display rounding), "minDigits": N}   or   {"error": kind}

The Swift test (TranscendentalFixtureTests) evaluates MathKernel at 60 digits and asserts
agreement to `minDigits` significant digits plus identical 16-digit display strings.

Run:  python3 -I Tools/gen_fixtures.py [--out DIR]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from decimal import Decimal  # noqa: E402
from fractions import Fraction  # noqa: E402

import mpmath  # noqa: E402

from calcref_common import CalcError, WORKING_DIGITS, canon, canon_display  # noqa: E402
from reference_model import Evaluator, literal_to_fraction  # noqa: E402

DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                           "Packages", "CalcEngine", "Tests", "CalcEngineTests", "Fixtures")

TRIG_RAD = ["0", "0.5", "1", "1.5", "2", "3", "3.5", "10", "100", "12345.678", "1e5", "-0.25", "-7",
            "1e-5", "1e-10", "0.7853981633974483", "1e15", "1e30"]
TRIG_DEG = ["0", "30", "45", "60", "90", "120", "135", "150", "180", "210", "225", "240", "270", "300",
            "315", "330", "360", "390", "720", "1000030", "-30", "-45", "-90", "12.5", "100", "1000",
            "33.3", "89.9", "0.001", "1e-10", "359.999"]
ASIN_IN = ["0", "0.5", "1", "-1", "0.1", "0.999", "-0.5", "0.7071067811865476", "0.3", "2", "-1.5"]
ATAN_IN = ["0", "1", "-1", "0.5", "10", "1e10", "1e-10", "-3.25", "1e-30"]
HYP_IN = ["0", "0.5", "1", "2", "10", "-3", "50", "1e-5", "-0.75"]
ASINH_IN = ["0", "1", "-2", "100", "0.001"]
ACOSH_IN = ["1", "2", "10", "1e5", "1.0001", "0.5"]
ATANH_IN = ["0", "0.5", "-0.9", "0.999", "1", "-1", "0.1"]
EXP_IN = ["0", "1", "-1", "0.5", "10", "100", "700", "-50", "1e-10", "2.302585092994046", "-745"]
LN_IN = ["1", "2", "0.5", "10", "1e-10", "1e100", "2.718281828459045", "0", "-1", "123456.789"]
LOG10_IN = ["1", "10", "2", "1000", "0.001", "123456", "1e-7", "3.1622776601683795", "0"]
LOG2_IN = ["1", "2", "8", "0.5", "10", "1024", "3", "0"]
SQRT_IN = ["2", "4", "0.25", "1e10", "123456789", "0", "-1", "3", "1e-20", "2.25"]
CBRT_IN = ["27", "-27", "2", "0.001", "0", "-2", "1e9"]
FACT_IN = ["0", "1", "5", "10", "20", "69", "170", "171", "500", "1000", "0.5", "2.5", "-0.5", "10.5",
           "-1", "20000", "20001", "100.25"]
INV_IN = ["4", "0.5", "0", "3", "-8", "1e-10"]
SQ_IN = ["1.5", "-2", "0", "1e200", "0.1"]
CUBE_IN = ["-2", "1.5", "0", "1e300"]
POW10_IN = ["3", "-2", "0.5", "0", "20", "-20", "308.5"]
POW2_IN = ["10", "0.5", "-1", "64", "0"]
POW_PAIRS = [("2", "0.5"), ("2", "10"), ("10", "-3"), ("1.5", "2.5"), ("2", "100"), ("0.5", "0.5"),
             ("9", "0.5"), ("27", "0.3333333333333333"), ("-8", "0.3333333333333333"), ("-2", "3"),
             ("-2", "-2"), ("0", "0"), ("0", "-1"), ("0", "5"), ("2", "4097"), ("99999", "99999"),
             ("10", "1000001"), ("1.0000001", "1e7"), ("4", "0.5"), ("8", "-0.3333333333333333"),
             ("2.5", "-1.5"), ("1e10", "0.1")]
ROOT_PAIRS = [("8", "3"), ("-8", "3"), ("16", "4"), ("-16", "4"), ("2", "2"), ("10", "3"),
              ("0.001", "3"), ("32", "5"), ("2", "0"), ("2", "-2"), ("1e30", "10"), ("5", "2.5"),
              ("0", "3"), ("1024", "10"), ("-32", "5")]


def rec_for(fn, args, angle=None, cid=None):
    ev = Evaluator(angle or "rad")
    vals = [literal_to_fraction(a) for a in args]
    rec = {"id": cid or (fn + ("_" + angle if angle else "") + "_" + "_".join(a.replace("-", "m").replace(".", "p") for a in args)),
           "fn": fn, "angle": angle, "args": args}
    try:
        if fn in ("pow", "root"):
            v = ev.power(vals[0], vals[1]) if fn == "pow" else ev.root(vals[0], vals[1])
        elif fn == "fact":
            v = ev.factorial(vals[0])
        else:
            v = ev.function(fn, vals[0])
        v = ev.evaluate(("num", "0")) if False else v  # keep evaluator API symmetrical
        from reference_model import check_overflow, norm
        v = norm(check_overflow(v))
        rec["exact"] = isinstance(v, Fraction)
        rec["expected"] = canon(v, WORKING_DIGITS)
        rec["expected16"] = canon_display(v)
        rec["minDigits"] = min_digits(fn, vals, angle)
    except CalcError as e:
        rec["error"] = e.kind
    return rec


def min_digits(fn, vals, angle):
    """How many significant digits we demand from BigDecimal at 60-digit working precision."""
    base = 52
    if fn in ("sin", "cos", "tan") and angle == "rad":
        x = abs(mpmath.mpf(vals[0].numerator) / vals[0].denominator)
        if x > 1:
            base -= int(mpmath.ceil(mpmath.log10(x)))   # argument reduction loses log10|x| digits
    if fn in ("sin", "cos", "tan") and angle == "deg":
        base = 50
    if fn == "fact" and vals[0].denominator != 1:
        base = 40   # Spouge approximation at 60 digits
    if fn in ("pow",) and vals[1].denominator != 1:
        base = 48
    if fn in ("root",) and vals[1].denominator != 1:
        base = 48
    return max(base, 30)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    cases = []
    for fn in ("sin", "cos", "tan"):
        cases += [rec_for(fn, [x], "rad") for x in TRIG_RAD]
        cases += [rec_for(fn, [x], "deg") for x in TRIG_DEG]
    for fn in ("asin", "acos"):
        cases += [rec_for(fn, [x], "rad") for x in ASIN_IN]
        cases += [rec_for(fn, [x], "deg") for x in ASIN_IN]
    cases += [rec_for("atan", [x], "rad") for x in ATAN_IN]
    cases += [rec_for("atan", [x], "deg") for x in ATAN_IN]
    for fn in ("sinh", "cosh", "tanh"):
        cases += [rec_for(fn, [x]) for x in HYP_IN]
    cases += [rec_for("asinh", [x]) for x in ASINH_IN]
    cases += [rec_for("acosh", [x]) for x in ACOSH_IN]
    cases += [rec_for("atanh", [x]) for x in ATANH_IN]
    cases += [rec_for("exp", [x]) for x in EXP_IN]
    cases += [rec_for("ln", [x]) for x in LN_IN]
    cases += [rec_for("log10", [x]) for x in LOG10_IN]
    cases += [rec_for("log2", [x]) for x in LOG2_IN]
    cases += [rec_for("sqrt", [x]) for x in SQRT_IN]
    cases += [rec_for("cbrt", [x]) for x in CBRT_IN]
    cases += [rec_for("fact", [x]) for x in FACT_IN]
    cases += [rec_for("inv", [x]) for x in INV_IN]
    cases += [rec_for("sq", [x]) for x in SQ_IN]
    cases += [rec_for("cube", [x]) for x in CUBE_IN]
    cases += [rec_for("pow10", [x]) for x in POW10_IN]
    cases += [rec_for("pow2", [x]) for x in POW2_IN]
    cases += [rec_for("pow", [a, b]) for a, b in POW_PAIRS]
    cases += [rec_for("root", [a, b]) for a, b in ROOT_PAIRS]

    ids = [c["id"] for c in cases]
    assert len(ids) == len(set(ids)), "duplicate fixture ids"

    with open(os.path.join(args.out, "transcendental.json"), "w", encoding="utf-8") as f:
        json.dump({"workingDigits": WORKING_DIGITS, "cases": cases}, f, indent=1, ensure_ascii=False)
        f.write("\n")
    errors = sum(1 for c in cases if "error" in c)
    print(f"transcendental.json: {len(cases)} cases ({errors} error cases)")


if __name__ == "__main__":
    main()
