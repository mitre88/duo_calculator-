# Vendored BigDecimal 3.0.2 (mgriebling/BigDecimal, MIT)

Verbatim copy of https://github.com/mgriebling/BigDecimal at tag 3.0.2 with **one** change so the
package also compiles against swift-foundation (Linux, where `Foundation.Decimal`'s storage fields
are internal):

* `BigDecimal.swift`: `init(_ value: Foundation.Decimal)` and `asDecimal()` keep the original
  field-level bridging under `#if canImport(Darwin)` and use the exact decimal **string** otherwise.

Everything else (DecimalMath, Decimal32/64/128, Rounding…) is untouched. The sibling
`Packages/Vendor/BigInt` is used for its `BigInt` dependency through SwiftPM identity override.
