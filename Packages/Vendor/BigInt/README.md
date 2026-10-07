# Vendored BigInt 2.3.0 (mgriebling/BigInt, MIT)

Verbatim copy of https://github.com/mgriebling/BigInt at tag 2.3.0 with **two** changes so the
package also builds on Linux (CI runs the engine tests there):

* `BigInt.swift`: `randomBytes` / `randomLimbs` use `SecRandomCopyBytes` only where the Security
  framework exists (`#if canImport(Security)`), and `SystemRandomNumberGenerator` elsewhere.
* `Package.swift`: the `BigIntTests` target is dropped because its sources are not vendored.

`Packages/CalcEngine/Package.swift` depends on this local copy; because it has the same package
identity (`bigint`), SwiftPM also uses it for BigDecimal's transitive dependency.
