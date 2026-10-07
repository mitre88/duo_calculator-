import Testing
@testable import CalcEngine

extension CalcEngineTests {
    /// Reference values from mpmath at 70 digits (`Tools/gen_fixtures.py`).
    @Suite struct TranscendentalFixtureTests {
        static let fixture = try! Fixtures.load("transcendental", as: TranscendentalFixture.self)

        static func compute(_ testCase: TranscendentalCase) throws -> CalcValue {
            let args = testCase.args.map(Numeric.value)
            let angle = Numeric.angle(testCase.angle)
            switch testCase.fn {
            case "pow": return try MathKernel.power(args[0], args[1])
            case "root": return try MathKernel.root(args[0], args[1])
            case "fact": return try MathKernel.factorial(args[0])
            default:
                guard let fn = UnaryFunction(rawValue: testCase.fn) else { throw CalcError.syntax }
                return try MathKernel.apply(fn, to: args[0], angle: angle)
            }
        }

        @Test(arguments: fixture.cases)
        func matchesMpmath(_ testCase: TranscendentalCase) throws {
            if let errorName = testCase.error {
                let expectedError = try #require(CalcError(fixtureName: errorName))
                #expect(throws: expectedError) { try Self.compute(testCase) }
                return
            }
            let value = try Self.compute(testCase)
            let expected = try #require(testCase.expected)
            #expect(value.isExact == (testCase.exact ?? false), "lane mismatch: \(value)")
            #expect(Numeric.agree(value, expected, digits: testCase.minDigits ?? 30),
                    "\(testCase.id): \(value.canonicalString(digits: 60)) vs \(expected)")
            #expect(Numeric.display16(value) == testCase.expected16, "\(testCase.id) display")
        }
    }
}
