import Foundation
import Testing
import BigInt
import BigDecimal
@testable import CalcEngine

extension CalcEngineTests {
    @Suite struct CalcValueTests {
        @Test func literalsAreExact() throws {
            let v = try #require(CalcValue(literal: "0.1"))
            #expect(v.isExact)
            #expect(v.exactFraction == BFraction(1, 10))
            #expect(CalcValue(literal: "1.5e3")?.exactFraction == BFraction(1500, 1))
            #expect(CalcValue(literal: ".25")?.exactFraction == BFraction(1, 4))
            #expect(CalcValue(literal: "-2.")?.exactFraction == BFraction(-2, 1))
            #expect(CalcValue(literal: "abc") == nil)
            #expect(CalcValue(literal: "") == nil)
        }

        @Test func canonicalStrings() {
            #expect(CalcValue(512).canonicalString() == "5.12E+2")
            #expect(CalcValue.zero.canonicalString() == "0E+0")
            #expect(Numeric.value("0.5").canonicalString() == "5E-1")
            #expect(Numeric.value("-1500").canonicalString() == "-1.5E+3")
            #expect(Numeric.value("1").canonicalString() == "1E+0")
            #expect(Numeric.value("0.000123").canonicalString(digits: 2) == "1.2E-4")
            #expect(Numeric.value("2.5").canonicalString(digits: 1) == "2E+0")  // half even
            #expect(Numeric.value("2.5").canonicalString(digits: 1, mode: .toNearestOrAwayFromZero) == "3E+0")
        }

        @Test func oversizedFractionsDemoteToApprox() {
            let big = CalcValue(exact: BFraction(powerOfTen(400), BInt.ONE))
            #expect(!big.isExact)
            #expect(big.decimalExponent == 400)
            let small = CalcValue(exact: BFraction(integerPower(BInt.TWO, 1000), BInt.ONE))
            #expect(small.isExact)
        }

        @Test func queries() {
            let third = Numeric.value("1") // placeholder for exact division below
            #expect(third.isInteger)
            #expect(third.asInt == 1)
            #expect(Numeric.value("-0.5").isNegative)
            #expect(Numeric.value("-0.5").signum == -1)
            #expect(Numeric.value("-0.5").magnitude == Numeric.value("0.5"))
            #expect(Numeric.value("1234.5").decimalExponent == 3)
            #expect(Numeric.value("0.001").decimalExponent == -3)
            #expect(CalcValue.zero.decimalExponent == nil)
            #expect(Numeric.value("3") < Numeric.value("4"))
            #expect(CalcValue(approx: BigDecimal("2.5")) < Numeric.value("3"))
        }

        @Test func codableRoundTrip() throws {
            let values: [CalcValue] = [.zero, Numeric.value("-1.25"), CalcValue(approx: BigDecimal.pi(Rounding(.toNearestOrEven, 60))), MathKernel.e()]
            for v in values {
                let data = try JSONEncoder().encode(v)
                let back = try JSONDecoder().decode(CalcValue.self, from: data)
                #expect(back == v)
            }
        }

        @Test func numberLiteralRoundTrips() {
            let literal = NumberLiteral(value: Numeric.value("-1500"))
            #expect(literal.isNegative)
            #expect(literal.mantissa == "1.5")
            #expect(literal.exponent == "3")
            #expect(literal.value == Numeric.value("-1500"))
            let typed = NumberLiteral(mantissa: "12.50", isNegative: false, exponent: "-2")
            #expect(typed.text == "12.50e-2")
            #expect(typed.value == Numeric.value("0.125"))
            #expect(NumberLiteral(mantissa: "0.").value == .zero)
            #expect(NumberLiteral(mantissa: "007").significantDigitCount == 1)
            #expect(NumberLiteral(mantissa: "1234.5").significantDigitCount == 5)
        }
    }
}
