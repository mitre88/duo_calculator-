# Vendored BigDecimal 3.0.2 (mgriebling/BigDecimal, MIT)

Verbatim copy of https://github.com/mgriebling/BigDecimal at tag 3.0.2 with **two** changes:

* `BigDecimal.swift`: `init(_ value: Foundation.Decimal)` and `asDecimal()` keep the original
  field-level bridging under `#if canImport(Darwin)` and use the exact decimal **string** otherwise,
  so the package also compiles against swift-foundation (Linux, where `Foundation.Decimal`'s storage
  fields are internal).
* `DecimalMath/DecimalMath.swift`: `init<T: BinaryInteger>(_:)` converts through `BInt` instead of
  accumulating base-10⁹ chunks with `addingProduct`, which rounds to `Rounding.decimal128`
  (34 digits). Upstream, every integer wider than 34 digits was silently truncated, so the
  Taylor-series calculators (`sin`, `cos`, `sinh`, `cosh`, `tanh`, …) divided by **rounded**
  factorials and lost 10–25 digits for |x| ≳ 5 whatever precision was requested
  (`sinh(50)` agreed with the true value to only 36 digits at 94 requested digits).
  Reproduced independently in Python by rounding the denominators to 34 digits.

* `Package.swift`: depends on the sibling `../BigInt` by path, pins the two remote dependencies to exact
  versions, and drops the `BigDecimalTests` target (its sources are not vendored).

Everything else (Decimal32/64/128, Rounding…) is untouched. The sibling
`Packages/Vendor/BigInt` is used for its `BigInt` dependency through SwiftPM identity override.
