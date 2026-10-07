import Testing
@testable import CalcEngine

extension CalcEngineTests {
    /// Every case of `expressions.json` was produced by the independent Python model (`Tools/reference_model.py`).
    @Suite struct ExpressionFixtureTests {
        static let fixture = try! Fixtures.load("expressions", as: ExpressionFixture.self)

        @Test(arguments: fixture.cases)
        func matchesReferenceModel(_ testCase: ExpressionCase) throws {
            let angle = Numeric.angle(testCase.angle)
            if let errorName = testCase.error {
                let expectedError = try #require(CalcError(fixtureName: errorName))
                #expect(throws: expectedError, "\(testCase.expr)") {
                    try Evaluator.evaluate(text: testCase.expr, angleMode: angle)
                }
                return
            }
            let value = try Evaluator.evaluate(text: testCase.expr, angleMode: angle)
            let expected = try #require(testCase.expected)
            #expect(value.isExact == (testCase.exact ?? false), "lane mismatch for \(testCase.expr): \(value)")
            if testCase.exact == true {
                #expect(value.canonicalString() == expected, "\(testCase.expr)")
            } else {
                #expect(Numeric.agree(value, expected, digits: 28), "\(testCase.expr) → \(value.canonicalString()) vs \(expected)")
            }
            #expect(Numeric.display16(value) == testCase.expected16, "display of \(testCase.expr)")
        }
    }
}
