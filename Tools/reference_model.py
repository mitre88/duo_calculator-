#!/usr/bin/env python3
"""Independent reference implementation of the CalcEngine grammar and semantics.

It mirrors Packages/CalcEngine (two numeric lanes, Pratt precedences, iOS percent
rules, degree tables, zero snaps, error kinds) and emits fixtures consumed by the
Swift tests:

    expressions.json     text expressions  -> canonical value / error kind
    ios_sequences.json   key sequences     -> display strings (hand-authored)
    formatting.json      formatter cases   -> display strings (hand-authored)

Run:  python3 -I Tools/reference_model.py [--out DIR]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from decimal import Decimal  # noqa: E402
from fractions import Fraction  # noqa: E402

import mpmath  # noqa: E402
from mpmath import mp, mpf  # noqa: E402

from calcref_common import (  # noqa: E402
    CANCELLATION_GUARD, CalcError, MAX_EXACT_FACTORIAL, MAX_GAMMA_ARG,
    MAX_INT_POWER_EXP, OVERFLOW_EXP, WORKING_DIGITS, ZERO_SNAP_ARG_EXP,
    ZERO_SNAP_EXP, canon, canon_display, literal_to_fraction,
)

DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                           "Packages", "CalcEngine", "Tests", "CalcEngineTests", "Fixtures")

# ----------------------------------------------------------------------------
# Tokenizer (text syntax used by tests, the `calc` CLI and paste)
# ----------------------------------------------------------------------------

FUNCTIONS = {
    "sin", "cos", "tan", "asin", "acos", "atan",
    "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
    "ln", "log10", "log2", "exp", "pow10", "pow2",
    "sqrt", "cbrt", "inv", "sq", "cube",
}
TWO_ARG_FUNCTIONS = {"root", "logb"}   # root(x, n) = n-th root of x ; logb(x, b) = log base b of x
CONSTANTS = {"pi", "e"}

BINARY_ALIASES = {"×": "*", "·": "*", "÷": "/", "−": "-", "–": "-"}


def tokenize(text: str):
    toks = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
            continue
        if c.isdigit() or (c == "." and i + 1 < n and text[i + 1].isdigit()):
            j = i
            while j < n and (text[j].isdigit() or text[j] == "."):
                j += 1
            # exponent part only if followed by digits (so "2e" is 2*e, "2e3" is 2000)
            if j < n and text[j] in "eE":
                k = j + 1
                if k < n and text[k] in "+-":
                    k += 1
                if k < n and text[k].isdigit():
                    while k < n and text[k].isdigit():
                        k += 1
                    j = k
            lit = text[i:j]
            if lit.count(".") > 1:
                raise CalcError("syntax")
            toks.append(("num", lit))
            i = j
            continue
        if c.isalpha():
            j = i
            while j < n and (text[j].isalnum()):
                j += 1
            word = text[i:j]
            if word in CONSTANTS:
                toks.append(("const", word))
            elif word in FUNCTIONS or word in TWO_ARG_FUNCTIONS:
                toks.append(("fn", word))
            else:
                raise CalcError("syntax")
            i = j
            continue
        c = BINARY_ALIASES.get(c, c)
        if c in "+-*/^":
            toks.append(("op", c))
        elif c == "(":
            toks.append(("lp", c))
        elif c == ")":
            toks.append(("rp", c))
        elif c == ",":
            toks.append(("comma", c))
        elif c in "!%":
            toks.append(("post", c))
        else:
            raise CalcError("syntax")
        i += 1
    return toks


# ----------------------------------------------------------------------------
# Pratt parser — binding powers are the single source of truth (OperatorTable.swift)
# ----------------------------------------------------------------------------

BINARY_BP = {"+": (10, 11), "-": (10, 11), "*": (20, 21), "/": (20, 21), "^": (50, 49)}
IMPLICIT_BP = (20, 21)
PREFIX_MINUS_BP = 30
PREFIX_FUNCTION_BP = 35
POSTFIX_BP = 60


class Parser:
    def __init__(self, tokens):
        self.toks = tokens
        self.pos = 0
        self.depth = 0

    def peek(self):
        return self.toks[self.pos] if self.pos < len(self.toks) else None

    def next(self):
        t = self.peek()
        if t is None:
            raise CalcError("syntax")
        self.pos += 1
        return t

    def parse(self):
        if not self.toks:
            raise CalcError("syntax")
        e = self.expr(0)
        if self.peek() is not None:
            raise CalcError("syntax")
        return e

    def starts_atom(self, t):
        return t is not None and (t[0] in ("num", "const", "fn", "lp"))

    def expr(self, min_bp):
        lhs = self.prefix()
        while True:
            t = self.peek()
            if t is None:
                break
            if t[0] == "post":
                if POSTFIX_BP < min_bp:
                    break
                self.next()
                lhs = ("post", t[1], lhs)
                continue
            if t[0] == "op":
                lbp, rbp = BINARY_BP[t[1]]
                if lbp < min_bp:
                    break
                self.next()
                rhs = self.expr(rbp)
                lhs = ("bin", t[1], lhs, rhs)
                continue
            if self.starts_atom(t):
                lbp, rbp = IMPLICIT_BP
                if lbp < min_bp:
                    break
                rhs = self.expr(rbp)
                lhs = ("bin", "*", lhs, rhs)
                continue
            break
        return lhs

    def prefix(self):
        t = self.next()
        kind, val = t
        if kind == "num":
            return ("num", val)
        if kind == "const":
            return ("const", val)
        if kind == "op" and val == "-":
            return ("neg", self.expr(PREFIX_MINUS_BP))
        if kind == "op" and val == "+":
            return self.expr(PREFIX_MINUS_BP)
        if kind == "lp":
            self.depth += 1
            if self.depth > 64:
                raise CalcError("tooComplex")
            inner = self.expr(0)
            if self.peek() is None:
                # auto-close is handled by the engine, text parser requires ')'
                raise CalcError("syntax")
            self.next()  # ')'
            self.depth -= 1
            return ("group", inner)
        if kind == "fn":
            name = val
            if name in TWO_ARG_FUNCTIONS:
                if self.peek() is None or self.peek()[0] != "lp":
                    raise CalcError("syntax")
                self.next()
                a = self.expr(0)
                if self.peek() is None or self.peek()[0] != "comma":
                    raise CalcError("syntax")
                self.next()
                b = self.expr(0)
                if self.peek() is None or self.peek()[0] != "rp":
                    raise CalcError("syntax")
                self.next()
                return ("fn2", name, a, b)
            if self.peek() is not None and self.peek()[0] == "lp":
                self.next()
                inner = self.expr(0)
                if self.peek() is None or self.peek()[0] != "rp":
                    raise CalcError("syntax")
                self.next()
                return ("fn", name, ("group", inner))
            # function applied without parentheses: binds tighter than × but looser than ^ / postfix
            return ("fn", name, self.expr(PREFIX_FUNCTION_BP))
        raise CalcError("syntax")


# ----------------------------------------------------------------------------
# Values: Fraction = exact lane, mpf = approx lane
# ----------------------------------------------------------------------------

def is_exact(v):
    return isinstance(v, Fraction)


def to_mpf(v):
    if isinstance(v, Fraction):
        return mpf(v.numerator) / mpf(v.denominator)
    return v


def is_zero(v):
    return v == 0


def is_negative(v):
    return v < 0


def is_integer(v):
    if isinstance(v, Fraction):
        return v.denominator == 1
    return mpmath.isint(v)


def too_big_fraction(fr: Fraction) -> bool:
    return fr.numerator.bit_length() + fr.denominator.bit_length() > 1024


def norm(v):
    """Demote oversized fractions to the approx lane (mirrors CalcValue.normalized)."""
    if isinstance(v, Fraction) and too_big_fraction(v):
        return to_mpf(v)
    return v


def decimal_exponent(x) -> int:
    """floor(log10(|x|)) for non-zero x."""
    if isinstance(x, Fraction):
        x = to_mpf(x)
    return int(mpmath.floor(mpmath.log10(abs(x))))


def check_overflow(v):
    if isinstance(v, Fraction):
        return v
    if mpmath.isinf(v) or mpmath.isnan(v):
        raise CalcError("overflow")
    if v != 0 and decimal_exponent(v) > OVERFLOW_EXP:
        raise CalcError("overflow")
    return v


# ---- snaps --------------------------------------------------------------------

def cancellation_snap(r, a, b):
    if r == 0:
        return Fraction(0)
    scale = max(abs(to_mpf(a)), abs(to_mpf(b)))
    if scale != 0 and abs(r) < mpf(10) ** (-(WORKING_DIGITS - CANCELLATION_GUARD)) * scale:
        return Fraction(0)
    return r


def zero_snap(r, arg):
    if is_exact(r):
        return r
    if r == 0:
        return Fraction(0)
    if abs(r) < mpf(10) ** ZERO_SNAP_EXP and abs(to_mpf(arg)) >= mpf(10) ** ZERO_SNAP_ARG_EXP:
        return Fraction(0)
    return r


# ---- exact helpers -----------------------------------------------------------

def exact_root(fr: Fraction, n: int):
    """n-th root of a non-negative fraction when both parts are perfect powers, else None."""
    if fr < 0:
        return None
    def iroot(k: int):
        if k < 2:
            return k
        r = round(k ** (1.0 / n)) if k.bit_length() < 1000 else None
        if r is None:
            # integer n-th root by Newton on big ints
            lo, hi = 0, 1 << (k.bit_length() // n + 1)
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if mid ** n <= k:
                    lo = mid
                else:
                    hi = mid - 1
            r = lo
        for cand in (r - 1, r, r + 1):
            if cand >= 0 and cand ** n == k:
                return cand
        return None
    num = iroot(fr.numerator)
    den = iroot(fr.denominator)
    if num is None or den is None:
        return None
    return Fraction(num, den)


# ---- angle tables --------------------------------------------------------------

SIN_TABLE = {   # degrees -> exact value, or None when irrational
    0: Fraction(0), 30: Fraction(1, 2), 45: None, 60: None, 90: Fraction(1),
    120: None, 135: None, 150: Fraction(1, 2), 180: Fraction(0),
    210: Fraction(-1, 2), 225: None, 240: None, 270: Fraction(-1),
    300: None, 315: None, 330: Fraction(-1, 2),
}
TAN_TABLE = {0: Fraction(0), 45: Fraction(1), 135: Fraction(-1), 180: Fraction(0),
             225: Fraction(1), 315: Fraction(-1)}
ASIN_TABLE = {Fraction(0): 0, Fraction(1, 2): 30, Fraction(1): 90,
              Fraction(-1, 2): -30, Fraction(-1): -90}
ACOS_TABLE = {Fraction(1): 0, Fraction(1, 2): 60, Fraction(0): 90,
              Fraction(-1, 2): 120, Fraction(-1): 180}
ATAN_TABLE = {Fraction(0): 0, Fraction(1): 45, Fraction(-1): -45}


def deg_to_rad(x):
    return to_mpf(x) * mp.pi / 180


def rad_to_deg(x):
    return x * 180 / mp.pi


# ----------------------------------------------------------------------------
# Evaluator
# ----------------------------------------------------------------------------

class Evaluator:
    def __init__(self, angle: str = "deg"):
        self.angle = angle

    # -- entry points -----------------------------------------------------------
    def evaluate(self, node):
        return norm(check_overflow(self._eval(node)))

    def _eval(self, node):
        kind = node[0]
        if kind == "num":
            return norm(literal_to_fraction(node[1]))
        if kind == "const":
            return mp.pi if node[1] == "pi" else mp.e
        if kind == "group":
            return self._eval(node[1])
        if kind == "neg":
            return -self._eval(node[1])
        if kind == "post":
            op, inner = node[1], node[2]
            x = self._eval(inner)
            if op == "%":
                return self.percent(x)
            if op == "!":
                return self.factorial(x)
            raise CalcError("syntax")
        if kind == "bin":
            return self.binary(node[1], node[2], node[3])
        if kind == "fn":
            return self.function(node[1], self._eval(node[2]))
        if kind == "fn2":
            return self.function2(node[1], self._eval(node[2]), self._eval(node[3]))
        raise CalcError("syntax")

    # -- percent ------------------------------------------------------------------
    def percent(self, x):
        return norm(x / 100) if is_exact(x) else x / 100

    def rhs_value(self, op, lhs_value, rhs_node):
        """iOS semantics: a ± b% → a ± a·b/100 ; a ×÷^ b% → a op (b/100)."""
        if rhs_node[0] == "post" and rhs_node[1] == "%":
            inner = self._eval(rhs_node[2])
            if op in ("+", "-"):
                return self.mul(lhs_value, self.percent(inner))
            return self.percent(inner)
        return self._eval(rhs_node)

    # -- arithmetic -------------------------------------------------------------------
    def add(self, a, b, sign=1):
        if is_exact(a) and is_exact(b):
            return norm(a + sign * b)
        r = to_mpf(a) + sign * to_mpf(b)
        return cancellation_snap(r, a, b)

    def mul(self, a, b):
        if is_exact(a) and is_exact(b):
            return norm(a * b)
        if is_zero(a) or is_zero(b):
            return Fraction(0)
        return to_mpf(a) * to_mpf(b)

    def div(self, a, b):
        if is_zero(b):
            raise CalcError("divisionByZero")
        if is_exact(a) and is_exact(b):
            return norm(a / b)
        if is_zero(a):
            return Fraction(0)
        return to_mpf(a) / to_mpf(b)

    def power(self, x, y):
        if is_zero(x):
            if is_zero(y):
                return Fraction(1)
            if is_negative(y):
                raise CalcError("divisionByZero")
            return Fraction(0)
        if is_exact(y) and y.denominator == 1:
            n = int(y)
            if is_exact(x) and abs(n) <= MAX_INT_POWER_EXP:
                return norm(x ** n)
            # magnitude guard then approx
            est = n * mpmath.log10(abs(to_mpf(x)))
            if est > OVERFLOW_EXP:
                raise CalcError("overflow")
            if est < -OVERFLOW_EXP:
                return Fraction(0)
            return mpmath.power(to_mpf(x), n)
        # non-integer exponent
        if is_negative(x):
            raise CalcError("domain")
        if is_exact(x) and is_exact(y) and y.denominator <= 64:
            r = exact_root(x, y.denominator)
            if r is not None and abs(y.numerator) <= MAX_INT_POWER_EXP:
                return norm(r ** y.numerator)
        xm, ym = to_mpf(x), to_mpf(y)
        est = ym * mpmath.log10(xm)
        if est > OVERFLOW_EXP:
            raise CalcError("overflow")
        if est < -OVERFLOW_EXP:
            return Fraction(0)
        return mpmath.power(xm, ym)

    def root(self, x, n):
        """n-th root of x (ʸ√x key: y = n)."""
        if is_zero(n) or is_negative(n):
            raise CalcError("domain")
        if is_exact(n) and n.denominator == 1:
            k = int(n)
            if is_negative(x):
                if k % 2 == 0:
                    raise CalcError("domain")
                return -self.root(-x, n)
            if is_zero(x):
                return Fraction(0)
            if is_exact(x) and k <= 64:
                r = exact_root(x, k)
                if r is not None:
                    return r
            return mpmath.root(to_mpf(x), k)
        if is_negative(x):
            raise CalcError("domain")
        if is_zero(x):
            return Fraction(0)
        return mpmath.power(to_mpf(x), 1 / to_mpf(n))

    def binary(self, op, lnode, rnode):
        a = self._eval(lnode)
        b = self.rhs_value(op, a, rnode)
        if op == "+":
            return self.add(a, b, 1)
        if op == "-":
            return self.add(a, b, -1)
        if op == "*":
            return self.mul(a, b)
        if op == "/":
            return self.div(a, b)
        if op == "^":
            return self.power(a, b)
        raise CalcError("syntax")

    # -- factorial -------------------------------------------------------------------
    def factorial(self, x):
        if is_negative(x):
            raise CalcError("domain")
        if is_integer(x):
            n = int(x) if is_exact(x) else int(to_mpf(x))
            if n > MAX_EXACT_FACTORIAL:
                raise CalcError("overflow")
            return norm(Fraction(math.factorial(n)))
        if to_mpf(x) > MAX_GAMMA_ARG:
            raise CalcError("overflow")
        return mpmath.gamma(to_mpf(x) + 1)

    # -- functions ---------------------------------------------------------------------
    def function(self, name, x):
        if name == "sq":
            return self.power(x, Fraction(2))
        if name == "cube":
            return self.power(x, Fraction(3))
        if name == "inv":
            return self.div(Fraction(1), x)
        if name == "sqrt":
            return self.root(x, Fraction(2))
        if name == "cbrt":
            return self.root(x, Fraction(3))
        if name == "pow10":
            return self.power(Fraction(10), x)
        if name == "pow2":
            return self.power(Fraction(2), x)
        if name == "exp":
            if is_zero(x):
                return Fraction(1)
            xm = to_mpf(x)
            est = xm / mpmath.log(10)
            if est > OVERFLOW_EXP:
                raise CalcError("overflow")
            if est < -OVERFLOW_EXP:
                return Fraction(0)
            return mpmath.exp(xm)
        if name in ("ln", "log10", "log2"):
            if is_zero(x) or is_negative(x):
                raise CalcError("domain")
            if is_exact(x):
                if x == 1:
                    return Fraction(0)
                base = {"ln": None, "log10": 10, "log2": 2}[name]
                if base is not None:
                    k = exact_log(x, base)
                    if k is not None:
                        return Fraction(k)
            xm = to_mpf(x)
            return {"ln": mpmath.log, "log10": mpmath.log10, "log2": lambda v: mpmath.log(v, 2)}[name](xm)
        if name in ("sin", "cos", "tan"):
            return self.trig(name, x)
        if name in ("asin", "acos", "atan"):
            return self.inverse_trig(name, x)
        if name in ("sinh", "cosh", "tanh", "asinh", "acosh", "atanh"):
            return self.hyperbolic(name, x)
        raise CalcError("syntax")

    def function2(self, name, a, b):
        if name == "root":
            return self.root(a, b)
        if name == "logb":
            if is_zero(a) or is_negative(a) or is_zero(b) or is_negative(b) or b == 1:
                raise CalcError("domain")
            if is_exact(a) and is_exact(b):
                if a == 1:
                    return Fraction(0)
                # exact when a = b^k
                k = exact_log_fraction(a, b)
                if k is not None:
                    return Fraction(k)
            return mpmath.log(to_mpf(a)) / mpmath.log(to_mpf(b))
        raise CalcError("syntax")

    # -- trig ----------------------------------------------------------------------------
    def trig(self, name, x):
        if self.angle == "deg":
            if is_exact(x):
                r = x % 360
                if r.denominator == 1 and int(r) in SIN_TABLE:
                    d = int(r)
                    if name == "sin":
                        v = SIN_TABLE[d]
                    elif name == "cos":
                        v = SIN_TABLE[(d + 90) % 360]
                    else:
                        if d in (90, 270):
                            raise CalcError("domain")
                        v = TAN_TABLE.get(d)
                    if v is not None:
                        return v
                rad = deg_to_rad(r)
            else:
                rad = deg_to_rad(to_mpf(x) % 360)   # reduce first, like MathKernel
        else:
            if is_exact(x) and x == 0:
                return Fraction(1) if name == "cos" else Fraction(0)
            rad = to_mpf(x)
        snap_arg = x if self.angle == "rad" else rad
        if name == "tan":
            # tan = sin / cos with the cosine snapped first, so tan(pi/2) is undefined, not 10^60-ish noise
            c = zero_snap(mpmath.cos(rad), snap_arg)
            if is_zero(c):
                raise CalcError("domain")
            return zero_snap(mpmath.sin(rad) / to_mpf(c), snap_arg)
        f = {"sin": mpmath.sin, "cos": mpmath.cos}[name]
        return zero_snap(f(rad), snap_arg)

    def inverse_trig(self, name, x):
        if name in ("asin", "acos") and (x > 1 or x < -1):
            raise CalcError("domain")
        if is_exact(x):
            table = {"asin": ASIN_TABLE, "acos": ACOS_TABLE, "atan": ATAN_TABLE}[name]
            if x in table:
                deg = table[x]
                if self.angle == "deg":
                    return Fraction(deg)
                if deg == 0:
                    return Fraction(0)
        f = {"asin": mpmath.asin, "acos": mpmath.acos, "atan": mpmath.atan}[name]
        r = f(to_mpf(x))
        if self.angle == "deg":
            r = rad_to_deg(r)
        return zero_snap(r, x)

    def hyperbolic(self, name, x):
        if name == "acosh" and x < 1:
            raise CalcError("domain")
        if name == "atanh" and (x >= 1 or x <= -1):
            raise CalcError("domain")
        if is_exact(x):
            if x == 0 and name in ("sinh", "tanh", "asinh", "atanh"):
                return Fraction(0)
            if x == 0 and name == "cosh":
                return Fraction(1)
            if x == 1 and name == "acosh":
                return Fraction(0)
        xm = to_mpf(x)
        if name in ("sinh", "cosh"):
            est = abs(xm) / mpmath.log(10)
            if est > OVERFLOW_EXP:
                raise CalcError("overflow")
        f = getattr(mpmath, name)
        return zero_snap(f(xm), x)


def exact_log(x: Fraction, base: int):
    """k such that base**k == x (k may be negative), else None."""
    if x.numerator == 1 and x.denominator > 1:
        k = exact_log(Fraction(x.denominator), base)
        return -k if k is not None else None
    if x.denominator != 1:
        return None
    n = x.numerator
    k = 0
    while n % base == 0 and n > 1:
        n //= base
        k += 1
    return k if n == 1 else None


def exact_log_fraction(a: Fraction, b: Fraction):
    if b.denominator != 1:
        return None
    return exact_log(a, int(b)) if b > 1 else None


# ----------------------------------------------------------------------------
# Public helpers
# ----------------------------------------------------------------------------

def evaluate_text(text: str, angle: str = "deg"):
    tree = Parser(tokenize(text)).parse()
    return Evaluator(angle).evaluate(tree)


def case(expr: str, angle: str = "deg", cid: str | None = None):
    rec = {"id": cid or auto_id(expr, angle), "expr": expr, "angle": angle}
    try:
        v = evaluate_text(expr, angle)
        rec["exact"] = is_exact(v)
        rec["expected"] = canon(v)
        rec["expected16"] = canon_display(v)
    except CalcError as e:
        rec["error"] = e.kind
    return rec


def auto_id(expr: str, angle: str) -> str:
    safe = "".join(ch if ch.isalnum() else "_" for ch in expr).strip("_")
    return f"{angle}_{safe[:48]}"


# ----------------------------------------------------------------------------
# Fixture content
# ----------------------------------------------------------------------------

EXPRESSIONS = [
    # exact arithmetic
    "0.1+0.2", "1/3*3-1", "1/3*3", "2+3*4", "(2+3)*4", "10-4-3", "100/10/5", "2^3^2", "(2^3)^2",
    "-2^2", "(-2)^2", "2^-3", "2^3!", "2^(3!)", "6/2(1+2)", "2(3)^2", "2(3+4)", "3(4+1)",
    "2*-3", "2--3", "2+-3", "-(2+3)", "--5", "1e3+1", "2e3*2", "1.5e-3*1000", "123456789*987654321",
    "0.000001*1000000", "1/7*7", "(1/3+1/6)*2", "22/7", "1/3", "2/3", "1/8", "1/1024", "7/4",
    "1234567890123456789+1", "0.1*3", "1-0.9", "0.3-0.1", "4.35*100", "1.1*1.1", "10/4", "9/3",
    # percent (iOS semantics)
    "50%", "200+10%", "200-10%", "50*10%", "50/10%", "10%*50", "2+3*10%", "100+100%", "0+5%",
    "25%+25%", "(200+10%)*2", "10%%",
    # powers & roots
    "2^0.5", "sqrt(2)", "sqrt(4)", "sqrt(0.25)", "sqrt(1e10)", "sqrt(2)^2", "sqrt(2)*sqrt(2)",
    "sqrt(2)*sqrt(2)-2", "cbrt(27)", "cbrt(-27)", "cbrt(2)", "root(8,3)", "root(-8,3)", "root(16,4)",
    "root(-16,4)", "root(2,2)", "root(10,3)", "root(0.001,3)", "root(32,5)", "4^0.5", "8^(1/3)",
    "(-8)^(1/3)", "27^(2/3)", "0^0", "0^-1", "0^5", "2^100", "2^1000", "2^4097", "10^-3", "10^20",
    "1.5^2.5", "9^0.5", "0.5^0.5", "2^10", "(-2)^3", "(-2)^-2", "99999^99999", "10^1000001",
    "inv(4)", "inv(0.5)", "inv(0)", "inv(3)", "sq(1.5)", "cube(-2)", "sq(sqrt(2))",
    # logs & exp
    "ln(1)", "ln(e)", "ln(2)", "ln(0)", "ln(-1)", "log10(1000)", "log10(0.001)", "log10(2)",
    "log10(10)", "log2(8)", "log2(0.5)", "log2(10)", "exp(0)", "exp(1)", "exp(-1)", "exp(10)",
    "exp(1000)", "exp(-1000)", "pow10(3)", "pow10(-2)", "pow10(0.5)", "pow2(10)", "pow2(0.5)",
    "logb(8,2)", "logb(1000,10)", "logb(10,3)", "logb(5,1)", "e^2", "e^ln(2)",
    # trig deg
    ("sin(30)", "deg"), ("sin(90)", "deg"), ("sin(180)", "deg"), ("sin(270)", "deg"), ("sin(360)", "deg"),
    ("sin(45)", "deg"), ("sin(60)", "deg"), ("sin(-30)", "deg"), ("sin(390)", "deg"), ("sin(1000030)", "deg"),
    ("cos(0)", "deg"), ("cos(60)", "deg"), ("cos(90)", "deg"), ("cos(180)", "deg"), ("cos(270)", "deg"),
    ("cos(45)", "deg"), ("tan(45)", "deg"), ("tan(90)", "deg"), ("tan(270)", "deg"), ("tan(135)", "deg"),
    ("tan(180)", "deg"), ("tan(30)", "deg"), ("tan(60)", "deg"), ("sin(12.5)", "deg"), ("cos(33.3)", "deg"),
    ("tan(89.9)", "deg"), ("sin(1e-10)", "deg"), ("sin(pi)", "deg"), ("sin(sqrt(2))", "deg"),
    ("asin(0.5)", "deg"), ("asin(1)", "deg"), ("asin(-1)", "deg"), ("asin(2)", "deg"), ("asin(0.3)", "deg"),
    ("acos(0.5)", "deg"), ("acos(0)", "deg"), ("acos(-1)", "deg"), ("acos(1)", "deg"), ("acos(1.5)", "deg"),
    ("atan(1)", "deg"), ("atan(-1)", "deg"), ("atan(0)", "deg"), ("atan(1e10)", "deg"), ("atan(0.5)", "deg"),
    ("sin(30)^2+cos(30)^2", "deg"), ("2sin(30)", "deg"), ("sin 30", "deg"), ("sin 30*2", "deg"),
    ("sin 30^2", "deg"), ("sin(30)*2", "deg"), ("asin(sin(30))", "deg"), ("sin(asin(0.3))", "deg"),
    # trig rad
    ("sin(pi)", "rad"), ("cos(pi)", "rad"), ("sin(pi/2)", "rad"), ("cos(pi/2)", "rad"), ("tan(pi/4)", "rad"),
    ("sin(0)", "rad"), ("cos(0)", "rad"), ("sin(1)", "rad"), ("cos(1)", "rad"), ("tan(1)", "rad"),
    ("sin(100)", "rad"), ("sin(1e5)", "rad"), ("sin(1e-45)", "rad"), ("sin(2pi)", "rad"), ("sin(pi/6)", "rad"),
    ("asin(0.5)", "rad"), ("acos(0)", "rad"), ("atan(1)", "rad"), ("atan(1)*4", "rad"), ("asin(1)", "rad"),
    ("sin(1)^2+cos(1)^2", "rad"), ("tan(pi/2)", "rad"),
    # hyperbolic
    "sinh(0)", "cosh(0)", "tanh(0)", "sinh(1)", "cosh(1)", "tanh(1)", "sinh(-3)", "cosh(10)", "tanh(50)",
    "asinh(0)", "asinh(1)", "acosh(1)", "acosh(2)", "acosh(0.5)", "atanh(0)", "atanh(0.5)", "atanh(1)",
    "atanh(-1)", "sinh(1e7)", "cosh(2)^2-sinh(2)^2",
    # factorial
    "0!", "1!", "5!", "10!", "20!", "69!", "170!", "171!", "500!", "1000!", "0.5!", "2.5!", "10.5!",
    "(-1)!", "(-0.5)!", "20000!", "20001!", "3!!", "(2+1)!", "2*3!", "-3!",
    # constants & implicit multiplication
    "pi", "2pi", "pi*2", "pi/pi", "e", "2e", "e*e", "pi^2", "(pi)", "2(pi)", "pi(2)", "2pi/2",
    # syntax errors
    "2+", "*2", "2**3", "()", "(2", "2)", "sin", "sin()", "1..2", "2+3)", "root(8)", "foo(2)",
    # mixed
    "sqrt(16)+2^3-5!", "(1+2)*(3+4)/7", "1/(2-2)", "1/(1-0.999999999999999999999)", "2^0.5*2^0.5",
    "10/3*3", "1e308*10", "1e-308/10", "123456789012345678901234567890*10", "0.1+0.2-0.3",
]

RANDOM_SEED = 20261023
RANDOM_CASES = 120


def random_arith_expressions(rng: random.Random):
    """Seeded random +−×÷ expressions over decimals — exact lane end to end."""
    out = []
    ops = ["+", "-", "*", "/"]
    for i in range(RANDOM_CASES):
        n = rng.randint(2, 5)
        parts = []
        for j in range(n):
            if rng.random() < 0.5:
                num = str(rng.randint(0, 99999))
            else:
                num = f"{rng.randint(0, 9999)}.{rng.randint(0, 999999):0{rng.randint(1, 6)}d}"
            if rng.random() < 0.15:
                num = "-" + num if j == 0 else num
            parts.append(num)
            if j < n - 1:
                parts.append(rng.choice(ops))
        expr = "".join(parts)
        if rng.random() < 0.3:
            # wrap a random sub-span in parentheses
            k = rng.randrange(0, n - 1)
            toks = parts[:]
            toks.insert(2 * k, "(")
            toks.insert(2 * k + 4, ")")
            expr = "".join(toks)
        out.append(case(expr, "deg", f"rand_{i:03d}"))
    return out


# Key names used by ios_sequences.json (mirrored by CalculatorEvent(testName:) in Swift).
IOS_SEQUENCES = [
    {"id": "basic_add", "keys": ["1", "2", "add", "3", "eq"], "primary": "15", "expression": "12 + 3 ="},
    {"id": "expression_while_typing", "keys": ["1", "2", "add", "3"], "primary": "3", "expression": "12 + 3"},
    {"id": "expression_function", "keys": ["3", "0", "sin", "mul", "2"], "primary": "2", "expression": "sin(30) × 2"},
    {"id": "expression_percent", "keys": ["2", "0", "0", "add", "1", "0", "pct"], "primary": "20", "expression": "200 + 10%"},
    {"id": "chain_no_eq", "keys": ["2", "add", "3", "mul"], "primary": "3"},
    {"id": "chain_no_eq_resolves", "keys": ["2", "mul", "3", "add"], "primary": "6"},
    {"id": "chain_no_eq_same_level", "keys": ["2", "add", "3", "add"], "primary": "5"},
    {"id": "precedence", "keys": ["2", "add", "3", "mul", "4", "eq"], "primary": "14"},
    {"id": "repeat_eq", "keys": ["2", "add", "3", "eq", "eq", "eq"], "primary": "11"},
    {"id": "repeat_eq_mul", "keys": ["2", "mul", "3", "eq", "eq"], "primary": "18"},
    {"id": "repeat_after_new_entry", "keys": ["2", "add", "3", "eq", "1", "0", "eq"], "primary": "13"},
    {"id": "trailing_op_eq", "keys": ["5", "mul", "eq"], "primary": "25"},
    {"id": "trailing_add_eq", "keys": ["2", "add", "eq"], "primary": "4"},
    {"id": "trailing_after_chain", "keys": ["2", "add", "3", "mul", "eq"], "primary": "11"},
    {"id": "operator_replace", "keys": ["6", "mul", "add", "3", "eq"], "primary": "9"},
    {"id": "minus_as_sign", "keys": ["2", "mul", "sub", "3", "eq"], "primary": "-6"},
    {"id": "percent_add", "keys": ["2", "0", "0", "add", "1", "0", "pct", "eq"], "primary": "220"},
    {"id": "percent_preview", "keys": ["2", "0", "0", "add", "1", "0", "pct"], "primary": "20"},
    {"id": "percent_sub", "keys": ["2", "0", "0", "sub", "1", "0", "pct", "eq"], "primary": "180"},
    {"id": "percent_mul", "keys": ["5", "0", "mul", "1", "0", "pct", "eq"], "primary": "5"},
    {"id": "percent_div", "keys": ["5", "0", "div", "1", "0", "pct", "eq"], "primary": "500"},
    {"id": "percent_alone", "keys": ["5", "0", "pct"], "primary": "0.5"},
    {"id": "percent_alone_eq", "keys": ["5", "0", "pct", "eq"], "primary": "0.5"},
    {"id": "sign_then_square", "keys": ["2", "neg", "sq"], "primary": "4"},
    {"id": "square_immediate", "keys": ["3", "sq"], "primary": "9"},
    {"id": "square_then_digit_replaces", "keys": ["3", "sq", "5"], "primary": "5"},
    {"id": "function_wraps", "keys": ["9", "sqrt", "add", "1", "eq"], "primary": "4"},
    {"id": "sqrt_negative_error", "keys": ["1", "neg", "sqrt"], "primary": "Error"},
    {"id": "div_zero", "keys": ["1", "div", "0", "eq"], "primary": "Error"},
    {"id": "error_recovery_digit", "keys": ["1", "div", "0", "eq", "7"], "primary": "7"},
    {"id": "error_recovery_ac", "keys": ["1", "div", "0", "eq", "ac"], "primary": "0"},
    {"id": "asin_out_of_domain", "keys": ["2", "asin"], "primary": "Error"},
    {"id": "clear_entry", "keys": ["1", "2", "add", "3", "4", "clear", "5", "eq"], "primary": "17"},
    {"id": "all_clear", "keys": ["1", "2", "add", "3", "ac", "5", "eq"], "primary": "5"},
    {"id": "backspace", "keys": ["1", "2", "3", "back"], "primary": "12"},
    {"id": "backspace_to_zero", "keys": ["7", "back"], "primary": "0"},
    {"id": "decimal_entry", "keys": ["dot", "5", "add", "dot", "2", "5", "eq"], "primary": "0.75"},
    {"id": "double_dot_ignored", "keys": ["1", "dot", "dot", "5"], "primary": "1.5"},
    {"id": "leading_zeros", "keys": ["0", "0", "7"], "primary": "7"},
    {"id": "grouping_entry", "keys": ["1", "2", "3", "4", "5", "6", "7"], "primary": "1,234,567"},
    {"id": "grouping_result", "keys": ["1", "0", "0", "0", "mul", "1", "0", "0", "0", "eq"], "primary": "1,000,000"},
    {"id": "ee_entry", "keys": ["1", "dot", "5", "ee", "3", "eq"], "primary": "1,500"},
    {"id": "ee_negative_exponent", "keys": ["2", "ee", "3", "neg", "eq"], "primary": "0.002"},
    {"id": "float_artifact_hidden", "keys": ["dot", "1", "add", "dot", "2", "eq"], "primary": "0.3"},
    {"id": "third_times_three", "keys": ["1", "div", "3", "mul", "3", "eq"], "primary": "1"},
    {"id": "sqrt2_squared", "keys": ["2", "sqrt", "sq"], "primary": "2"},
    {"id": "power_right_assoc", "keys": ["2", "pow", "3", "pow", "2", "eq"], "primary": "512"},
    {"id": "parens", "keys": ["lp", "2", "add", "3", "rp", "mul", "4", "eq"], "primary": "20"},
    {"id": "parens_autoclose", "keys": ["lp", "2", "add", "3", "mul", "4", "eq"], "primary": "14"},
    {"id": "implicit_mul_paren", "keys": ["2", "lp", "3", "add", "4", "rp", "eq"], "primary": "14"},
    {"id": "pi_times_two", "keys": ["2", "pi", "eq"], "primary": "6.283185307179586"},
    {"id": "pi_alone", "keys": ["pi"], "primary": "3.141592653589793"},
    {"id": "e_alone", "keys": ["e"], "primary": "2.718281828459045"},
    {"id": "sin_30_deg", "keys": ["3", "0", "sin"], "primary": "0.5"},
    {"id": "cos_90_deg", "keys": ["9", "0", "cos"], "primary": "0"},
    {"id": "tan_90_deg_error", "keys": ["9", "0", "tan"], "primary": "Error"},
    {"id": "sin_pi_rad", "keys": ["rad", "pi", "sin"], "primary": "0"},
    {"id": "ln_e", "keys": ["e", "ln"], "primary": "1"},
    {"id": "factorial_5", "keys": ["5", "fact"], "primary": "120"},
    {"id": "factorial_170", "keys": ["1", "7", "0", "fact"], "primary": "7.257415615307999e306"},
    {"id": "factorial_half", "keys": ["dot", "5", "fact"], "primary": "0.886226925452758"},
    {"id": "big_sci", "keys": ["9", "9", "9", "9", "9", "9", "9", "9", "mul", "9", "9", "9", "9", "9", "9", "9", "9", "9", "eq"], "primary": "9.99999989e16"},
    {"id": "tiny_sci", "keys": ["1", "div", "1", "0", "0", "0", "0", "0", "0", "0", "0", "eq"], "primary": "1e-8"},
    {"id": "memory_add_recall", "keys": ["5", "mplus", "ac", "3", "add", "mr", "eq"], "primary": "8"},
    {"id": "memory_sub", "keys": ["5", "mplus", "2", "mminus", "ac", "mr"], "primary": "3"},
    {"id": "memory_clear", "keys": ["5", "mplus", "mc", "mr"], "primary": "0"},
    {"id": "second_asin", "keys": ["dot", "5", "second", "sin"], "primary": "30"},
    {"id": "second_toggles_off", "keys": ["second", "second", "3", "0", "sin"], "primary": "0.5"},
    {"id": "cursor_insert_middle", "keys": ["1", "add", "3", "left", "left", "2", "eq"], "primary": "15"},
    {"id": "cursor_delete_middle", "keys": ["1", "2", "add", "3", "left", "left", "back", "eq"], "primary": "4"},
    {"id": "recall_result_chain", "keys": ["7", "mul", "6", "eq", "sub", "2", "eq"], "primary": "40"},
    {"id": "digit_after_result_starts_fresh", "keys": ["7", "mul", "6", "eq", "9"], "primary": "9"},
    {"id": "op_at_start_uses_zero", "keys": ["add", "5", "eq"], "primary": "5"},
    {"id": "neg_zero_entry_echo", "keys": ["0", "neg"], "primary": "-0"},
    {"id": "neg_zero_result_normalized", "keys": ["0", "neg", "eq"], "primary": "0"},
    {"id": "neg_on_empty_ignored", "keys": ["neg"], "primary": "0"},
    {"id": "memory_add_ends_entry", "keys": ["5", "mplus", "2"], "primary": "2"},
    {"id": "neg_on_entry", "keys": ["5", "neg", "neg"], "primary": "5"},
    {"id": "inv_zero_error", "keys": ["0", "inv"], "primary": "Error"},
    {"id": "entry_digit_cap", "keys": ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "1", "2", "3", "4", "5", "6", "7", "8"], "primary": "1,234,567,890,123,456"},
    # Quality-review regressions
    {"id": "percent_repeat_equals", "keys": ["2", "0", "0", "add", "1", "0", "pct", "eq", "eq"], "primary": "240", "expression": "220 + 20 ="},
    {"id": "percent_subtract_repeat_equals", "keys": ["2", "0", "0", "sub", "1", "0", "pct", "eq", "eq"], "primary": "160"},
    {"id": "percent_multiply_repeat_equals", "keys": ["5", "0", "mul", "1", "0", "pct", "eq", "eq"], "primary": "0.5"},
    {"id": "negate_constant", "keys": ["pi", "neg"], "primary": "-3.141592653589793"},
    {"id": "negate_function_result", "keys": ["3", "0", "sin", "neg"], "primary": "-0.5"},
    {"id": "negate_parenthesised", "keys": ["lp", "2", "add", "3", "rp", "neg"], "primary": "-5"},
    {"id": "negate_square", "keys": ["5", "sq", "neg"], "primary": "-25"},
    {"id": "negate_constant_memory", "keys": ["pi", "neg", "mplus", "ac", "mr"], "primary": "-3.141592653589793"},
    {"id": "negate_then_equals", "keys": ["pi", "neg", "eq"], "primary": "-3.141592653589793"},
    {"id": "insert_operator_before_operator", "keys": ["1", "mul", "3", "left", "left", "add", "eq"], "primary": "4", "expression": "1 + 3 ="},
    {"id": "approx_zero_factorial", "keys": ["e", "ln", "ln", "fact"], "primary": "1"},
]

FORMATTING = [
    {"value": "1234567.891", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1,234,567.891"},
    {"value": "1234567.891", "profile": "regular", "locale": "de_DE", "grouping": True, "expected": "1.234.567,891"},
    {"value": "1234567.891", "profile": "regular", "locale": "es_MX", "grouping": True, "expected": "1,234,567.891"},
    {"value": "1234567.891", "profile": "regular", "locale": "en_US", "grouping": False, "expected": "1234567.891"},
    {"value": "0.1", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "0.1"},
    {"value": "-0.5", "profile": "regular", "locale": "de_DE", "grouping": True, "expected": "-0,5"},
    {"value": "100", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "100"},
    {"value": "1000", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1,000"},
    {"value": "1234567890123456", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1,234,567,890,123,456"},
    {"value": "12345678901234567", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1.234567890123457e16"},
    {"value": "123456789012", "profile": "compact", "locale": "en_US", "grouping": True, "expected": "123,456,789,012"},
    {"value": "1234567890123", "profile": "compact", "locale": "en_US", "grouping": True, "expected": "1.23456789012e12"},
    {"value": "0.000001", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "0.000001"},
    {"value": "0.0000001", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1e-7"},
    {"value": "0.00000012345", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1.2345e-7"},
    {"value": "3.14159265358979323846", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "3.141592653589793"},
    {"value": "3.14159265358979323846", "profile": "compact", "locale": "en_US", "grouping": True, "expected": "3.14159265359"},
    {"value": "2.5", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "2.5"},
    {"value": "0.99999999999999999", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1"},
    {"value": "-0", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "0"},
    {"value": "1e100", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1e100"},
    {"value": "-1.5e-30", "profile": "regular", "locale": "de_DE", "grouping": True, "expected": "-1,5e-30"},
    {"value": "7.257415615307994e306", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "7.257415615307994e306"},
    {"value": "123.4500", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "123.45"},
    {"value": "999999999999999.9", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "999,999,999,999,999.9"},
    {"value": "9999999999999999.5", "profile": "regular", "locale": "en_US", "grouping": True, "expected": "1e16"},
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--selftest", action="store_true", help="print a few evaluations and exit")
    args = ap.parse_args()

    if args.selftest:
        for e in ["2^3^2", "200+10%", "sin(30)", "1/3*3-1", "sqrt(2)*sqrt(2)-2", "6/2(1+2)", "-2^2", "0.5!"]:
            print(e, "=>", case(e))
        return

    os.makedirs(args.out, exist_ok=True)
    rng = random.Random(RANDOM_SEED)
    cases = []
    seen = set()
    for item in EXPRESSIONS:
        expr, angle = (item, "deg") if isinstance(item, str) else item
        rec = case(expr, angle)
        if rec["id"] in seen:
            rec["id"] += "_b"
        seen.add(rec["id"])
        cases.append(rec)
    cases.extend(random_arith_expressions(rng))

    with open(os.path.join(args.out, "expressions.json"), "w", encoding="utf-8") as f:
        json.dump({"workingDigits": WORKING_DIGITS, "canonDigits": 30, "cases": cases}, f, indent=1, ensure_ascii=False)
        f.write("\n")
    with open(os.path.join(args.out, "ios_sequences.json"), "w", encoding="utf-8") as f:
        json.dump({"locale": "en_US", "profile": "regular", "angle": "deg", "cases": IOS_SEQUENCES}, f, indent=1, ensure_ascii=False)
        f.write("\n")
    with open(os.path.join(args.out, "formatting.json"), "w", encoding="utf-8") as f:
        json.dump({"cases": FORMATTING}, f, indent=1, ensure_ascii=False)
        f.write("\n")
    errors = sum(1 for c in cases if "error" in c)
    print(f"expressions.json: {len(cases)} cases ({errors} error cases); ios_sequences.json: {len(IOS_SEQUENCES)}; formatting.json: {len(FORMATTING)}")


if __name__ == "__main__":
    main()
