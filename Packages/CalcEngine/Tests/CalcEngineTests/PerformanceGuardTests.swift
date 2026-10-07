import Testing
@testable import CalcEngine

extension CalcEngineTests {
    /// Catches algorithmic blow-ups (exact BInt powers, huge factorials) rather than measuring speed precisely.
    @Suite struct PerformanceGuardTests {
        static let budget: Duration = .seconds(3)

        func timed(_ label: String, _ body: () throws -> CalcValue) throws {
            let clock = ContinuousClock()
            let start = clock.now
            _ = try body()
            let elapsed = clock.now - start
            #expect(elapsed < Self.budget, "\(label) took \(elapsed)")
        }

        @Test func heavyOperationsStayBounded() throws {
            try timed("99999^99999") { try MathKernel.power(CalcValue(99_999), CalcValue(99_999)) }
            try timed("20000!") { try MathKernel.factorial(CalcValue(20_000)) }
            try timed("sin(1e30)") { try MathKernel.apply(.sin, to: Numeric.value("1e30"), angle: .radians) }
            try timed("100.25!") { try MathKernel.factorial(Numeric.value("100.25")) }
            try timed("exp(2e6)") { try MathKernel.apply(.exp, to: Numeric.value("2000000"), angle: .radians) }
            try timed("2^4097") { try MathKernel.power(CalcValue(2), CalcValue(4097)) }
            try timed("1.0000001^1e7") { try MathKernel.power(Numeric.value("1.0000001"), Numeric.value("1e7")) }
        }

        @Test func engineKeyLatency() throws {
            var engine = CalculatorEngine()
            let clock = ContinuousClock()
            let start = clock.now
            for _ in 0..<50 {
                for e in [CalculatorEvent.digit(3), .function(.sin), .binary(.add), .digit(2), .postfix(.factorial), .equals] {
                    engine.send(e)
                    _ = engine.snapshot(formatter: .regularUS)
                }
            }
            let elapsed = clock.now - start
            #expect(elapsed < .seconds(5), "300 key presses took \(elapsed)")
        }
    }
}
