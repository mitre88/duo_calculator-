import Foundation
import Testing
import BigDecimal
@testable import CalcEngine

extension CalcEngineTests {
    /// Regressions found by the quality review; every test reproduces a bug that was fixed.
    @Suite struct ReviewRegressionTests {
        @Test func approxZeroBehavesLikeTheExactZero() throws {
            let settled = try MathKernel.settle(BigDecimal.zero)
            #expect(settled.isExact && settled.isZero)
            #expect(CalcValue(approx: BigDecimal.zero).asInt == 0)
            #expect(try MathKernel.factorial(CalcValue(approx: BigDecimal.zero)) == .one)
            #expect(try MathKernel.power(CalcValue(-2), settled) == .one)
            #expect(try MathKernel.power(CalcValue(-2), CalcValue(approx: BigDecimal.zero)) == .one)
            // ln(ln(e)) is an approx zero; its factorial is 1, not an overflow error.
            #expect(try Evaluator.evaluate(text: "ln(ln(e))!") == .one)
        }

        @Test func rootsBeyondDoubleRangeStayFinite() throws {
            let tiny = try #require(CalcValue(literal: "1e-400"))
            #expect(!tiny.isExact)
            #expect(Numeric.agree(try MathKernel.root(tiny, CalcValue(2)), "1E-200", digits: 50))
            let huge = try #require(CalcValue(literal: "1e402"))
            #expect(Numeric.agree(try MathKernel.root(huge, CalcValue(3)), "1E+134", digits: 50))
            #expect(Numeric.agree(try MathKernel.root(tiny, Numeric.value("2.5")), "1E-160", digits: 50))
        }

        @Test func radianTrigScalesPrecisionWithTheArgument() throws {
            let x30 = try #require(CalcValue(literal: "1e30"))
            #expect(Numeric.agree(try MathKernel.trig(.sin, x30, angle: .radians),
                                  "-0.090116901912138058030386428952987330274396332993043449885460667", digits: 55))
            let x100 = try #require(CalcValue(literal: "1e100"))
            #expect(Numeric.agree(try MathKernel.trig(.sin, x100, angle: .radians),
                                  "-0.37237612366127668826208669555316429571966788356743470236441539", digits: 55))
            let tooLarge = try #require(CalcValue(literal: "1e301"))
            #expect(throws: CalcError.self) { try MathKernel.trig(.sin, tooLarge, angle: .radians) }
        }

        @Test func largeHyperbolicArgumentsAreFastAndAccurate() throws {
            let clock = ContinuousClock()
            let start = clock.now
            let huge = try #require(CalcValue(literal: "1e300"))
            #expect(try MathKernel.hyperbolic(.tanh, huge) == CalcValue(approx: BigDecimal.one))
            #expect(try MathKernel.hyperbolic(.tanh, huge.negated) == CalcValue(approx: -BigDecimal.one))
            #expect(throws: CalcError.self) { try MathKernel.hyperbolic(.sinh, huge) }   // overflow, not a hang
            let x = CalcValue(100_000)
            #expect(Numeric.agree(try MathKernel.hyperbolic(.sinh, x), "1.40333168021306158965919290928587135426818313528294327269372E+43429", digits: 55))
            #expect(Numeric.agree(try MathKernel.hyperbolic(.cosh, x), "1.40333168021306158965919290928587135426818313528294327269372E+43429", digits: 55))
            #expect(Numeric.agree(try MathKernel.hyperbolic(.sinh, CalcValue(-25)), "-3.60024496686929362620737317611305969473144360248245959396555E+10", digits: 55))
            #expect(Numeric.agree(try MathKernel.hyperbolic(.tanh, CalcValue(20)),
                                  "0.99999999999999999150329148941682204543855819119098725713047456", digits: 55))
            #expect(clock.now - start < .seconds(5), "large hyperbolic arguments took \(clock.now - start)")
        }

        @Test func hugeExponentsNeverAlignOrExpandExactly() throws {
            let clock = ContinuousClock()
            let start = clock.now
            let big = CalcValue(approx: BigDecimal(1, 999_999))            // 1e999999, just under the overflow limit
            #expect(try MathKernel.add(big, .one) == big)
            #expect(try MathKernel.subtract(.one, big) == big.negated)
            #expect(try MathKernel.add(big, .zero) == big)
            // 10^k mod 360 is 280 for every k ≥ 3, so sin(1e999999°) = sin(280°).
            #expect(Numeric.agree(try MathKernel.trig(.sin, big, angle: .degrees), "-0.98480775301220805936674302458952301367064325171984241879002575", digits: 55))
            // An exact 10^300 raised to 3000 would be a 3-million-bit integer; it goes through exp(log) instead.
            let tenTo300 = try #require(CalcValue(literal: "1e300"))
            #expect(tenTo300.isExact)
            let powered = try MathKernel.power(tenTo300, CalcValue(3000))
            #expect(!powered.isExact && Numeric.agree(powered, "1E+900000", digits: 55))
            #expect(throws: CalcError.self) { try MathKernel.power(tenTo300, CalcValue(4000)) }   // overflow
            #expect(Numeric.agree(try MathKernel.root(CalcValue(approx: BigDecimal(1, 1000)), CalcValue(200)), "1E+5", digits: 55))
            #expect(clock.now - start < .seconds(3), "pathological inputs took \(clock.now - start)")
        }

        @Test func programmerEntryRespectsTheWordSize() {
            var engine = ProgrammerEngine()
            engine.send(.setWidth(.eight))
            for digit in [3, 0, 0] { engine.send(.digit(digit)) }
            #expect(engine.value.unsignedValue == 30)   // the third digit would overflow 8 bits and is ignored
            engine.send(.allClear)
            engine.send(.setRadix(.hexadecimal))
            for digit in [15, 15, 15] { engine.send(.digit(digit)) }
            #expect(engine.value.unsignedValue == 0xFF)
        }

        @Test func programmerErrorAbandonsThePendingChain() {
            var engine = ProgrammerEngine()
            for event in [ProgrammerEvent.digit(7), .binary(.divide), .digit(0), .binary(.add)] { engine.send(event) }
            #expect(engine.isError)
            for event in [ProgrammerEvent.digit(3), .binary(.add), .digit(3), .equals] { engine.send(event) }
            #expect(!engine.isError)
            #expect(engine.value.unsignedValue == 6)   // not 7 ÷ 3 = 2 from the stale pending operator
        }

        @Test func angleConversionsAreExactWhenPiCancels() throws {
            let degree = try #require(UnitCatalog.unit(id: "degree"))
            let gradian = try #require(UnitCatalog.unit(id: "gradian"))
            let arcminute = try #require(UnitCatalog.unit(id: "arcminute"))
            let radian = try #require(UnitCatalog.unit(id: "radian"))
            let gon = try UnitConverter.convert(CalcValue(90), from: degree, to: gradian)
            #expect(gon.isExact && gon == CalcValue(100))
            let minutes = try UnitConverter.convert(CalcValue(1), from: degree, to: arcminute)
            #expect(minutes.isExact && minutes == CalcValue(60))
            let rad = try UnitConverter.convert(CalcValue(180), from: degree, to: radian)
            #expect(!rad.isExact && Numeric.agree(rad, "3.14159265358979323846264338327950288419716939937510582097494459", digits: 55))
            let celsius = try #require(UnitCatalog.unit(id: "celsius"))
            let fahrenheit = try #require(UnitCatalog.unit(id: "fahrenheit"))
            let boiling = try UnitConverter.convert(CalcValue(100), from: celsius, to: fahrenheit)
            #expect(boiling.isExact && boiling == CalcValue(212))
        }
    }
}
