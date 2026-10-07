import Foundation
import Testing
import BigDecimal
@testable import CalcEngine

extension CalcEngineTests {
    @Suite struct IdentityPropertyTests {
        static let samples: [String] = {
            var rng = SeededRandomSource(seed: 2026)
            return (0..<24).map { _ in
                let u = rng.nextUnitValue().doubleValue
                return String(format: "%.6f", (u - 0.5) * 20)
            }
        }()

        static func close(_ a: CalcValue, _ b: CalcValue, digits: Int) -> Bool {
            let x = a.approx(Rounding(.toNearestOrEven, 70)), y = b.approx(Rounding(.toNearestOrEven, 70))
            if y.isZero { return x.abs < BigDecimal(1, -digits) }
            return (x - y).abs <= y.abs.multiply(BigDecimal(1, -digits), Rounding(.toNearestOrEven, 20))
        }

        @Test(arguments: Self.samples)
        func pythagoreanIdentity(x: String) throws {
            let v = Numeric.value(x)
            let s = try MathKernel.apply(.sin, to: v, angle: .radians)
            let c = try MathKernel.apply(.cos, to: v, angle: .radians)
            let sum = try MathKernel.add(MathKernel.power(s, CalcValue(2)), MathKernel.power(c, CalcValue(2)))
            #expect(Self.close(sum, .one, digits: 55), "sin²+cos² for \(x) = \(sum)")
        }

        @Test(arguments: Self.samples)
        func expLogRoundTrip(x: String) throws {
            let v = Numeric.value(x).magnitude
            guard !v.isZero else { return }
            let back = try MathKernel.apply(.exp, to: MathKernel.apply(.ln, to: v, angle: .radians), angle: .radians)
            #expect(Self.close(back, v, digits: 55), "exp(ln \(x))")
        }

        @Test(arguments: Self.samples)
        func powerRootRoundTrip(x: String) throws {
            let v = Numeric.value(x).magnitude
            guard !v.isZero else { return }
            let y = Numeric.value("2.5")
            let powered = try MathKernel.power(v, y)
            let back = try MathKernel.power(powered, MathKernel.divide(.one, y))
            #expect(Self.close(back, v, digits: 54), "(x^y)^(1/y) for \(x)")
        }

        @Test func degreesAndRadiansAgree() throws {
            let deg = try MathKernel.apply(.sin, to: CalcValue(30), angle: .degrees)
            let rad = try MathKernel.apply(.sin, to: MathKernel.divide(MathKernel.pi(), CalcValue(6)), angle: .radians)
            #expect(deg.isExact && deg == Numeric.value("0.5"))
            #expect(Self.close(rad, deg, digits: 55))
            let asinDeg = try MathKernel.apply(.asin, to: Numeric.value("0.3"), angle: .degrees)
            let asinRad = try MathKernel.apply(.asin, to: Numeric.value("0.3"), angle: .radians)
            let converted = try MathKernel.divide(MathKernel.multiply(asinRad, CalcValue(180)), MathKernel.pi())
            #expect(Self.close(asinDeg, converted, digits: 55))
        }

        @Test(arguments: ["0.3", "-0.9", "0.999999", "1e-10"])
        func inverseTrigRoundTrip(x: String) throws {
            let v = Numeric.value(x)
            let back = try MathKernel.apply(.sin, to: MathKernel.apply(.asin, to: v, angle: .radians), angle: .radians)
            #expect(Self.close(back, v, digits: 50), "sin(asin \(x))")
        }

        @Test func domainGuardsNeverCrash() {
            let bad: [(UnaryFunction, String)] = [
                (.asin, "2"), (.acos, "-1.5"), (.atanh, "1"), (.acosh, "0.5"), (.ln, "0"), (.ln, "-1"),
                (.log10, "0"), (.log2, "-8"), (.sqrt, "-4"), (.reciprocal, "0"),
            ]
            for (fn, arg) in bad {
                #expect(throws: (any Error).self, "\(fn)(\(arg))") {
                    try MathKernel.apply(fn, to: Numeric.value(arg), angle: .radians)
                }
            }
            #expect(throws: CalcError.domain) { try MathKernel.factorial(Numeric.value("-1")) }
            #expect(throws: CalcError.domain) { try MathKernel.root(Numeric.value("-16"), CalcValue(4)) }
            #expect(throws: CalcError.divisionByZero) { try MathKernel.power(.zero, CalcValue(-1)) }
            #expect(throws: CalcError.overflow) { try MathKernel.power(CalcValue(10), CalcValue(1_000_001)) }
            #expect(throws: CalcError.overflow) { try MathKernel.factorial(CalcValue(20_001)) }
        }

        @Test func exactSpecialValues() throws {
            #expect(try MathKernel.apply(.cos, to: CalcValue(90), angle: .degrees) == .zero)
            #expect(try MathKernel.apply(.sin, to: CalcValue(1_000_030), angle: .degrees).isExact == false)
            #expect(try MathKernel.apply(.sin, to: CalcValue(1_000_030), angle: .degrees).canonicalString(digits: 16) ==
                    (try MathKernel.apply(.sin, to: CalcValue(310), angle: .degrees).canonicalString(digits: 16)))
            #expect(try MathKernel.apply(.sin, to: MathKernel.pi(), angle: .radians) == .zero)
            #expect(try MathKernel.apply(.log10, to: CalcValue(1000), angle: .radians) == CalcValue(3))
            #expect(try MathKernel.apply(.log2, to: Numeric.value("0.5"), angle: .radians) == CalcValue(-1))
            #expect(try MathKernel.root(CalcValue(-8), CalcValue(3)) == CalcValue(-2))
            #expect(try MathKernel.power(CalcValue(27), Numeric.value("2").negated).isExact)
            #expect(try MathKernel.factorial(CalcValue(5)) == CalcValue(120))
            #expect(try MathKernel.apply(.tan, to: CalcValue(45), angle: .degrees) == .one)
        }
    }
}
