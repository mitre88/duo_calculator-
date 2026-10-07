import Testing
@testable import CalcEngine

extension CalcEngineTests {
    @Suite struct ParserTests {
        static let precedenceTable: [(String, String)] = [
            ("2+3*4", "1.4E+1"),
            ("(2+3)*4", "2E+1"),
            ("2^3^2", "5.12E+2"),
            ("(2^3)^2", "6.4E+1"),
            ("-2^2", "-4E+0"),
            ("(-2)^2", "4E+0"),
            ("2^-3", "1.25E-1"),
            ("2^3!", "6.4E+1"),
            ("6/2(1+2)", "9E+0"),
            ("2(3)^2", "1.8E+1"),
            ("2*-3", "-6E+0"),
            ("2--3", "5E+0"),
            ("--5", "5E+0"),
            ("10-4-3", "3E+0"),
            ("100/10/5", "2E+0"),
            ("2pi/2", "3.14159265358979323846264338328E+0"),
            ("sin 30^2", "0E+0"),
            ("sin 30*2", "1E+0"),
            ("2sin(30)", "1E+0"),
            ("3!!", "7.2E+2"),
            ("-3!", "-6E+0"),
            ("2^3²", "5.12E+2"),
            ("root(8,3)+logb(8,2)", "5E+0"),
            ("rpow(3,2)", "8E+0"),
        ]

        @Test(arguments: Self.precedenceTable)
        func precedence(expression: String, expected: String) throws {
            let value = try Evaluator.evaluate(text: expression, angleMode: .degrees)
            #expect(value.canonicalString() == expected, "\(expression)")
        }

        @Test(arguments: ["2+", "*2", "2**3", "()", "(2", "2)", "sin", "sin()", "1..2", "2+3)", "root(8)", "foo(2)", "", "2,3"])
        func syntaxErrors(expression: String) {
            #expect(throws: CalcError.syntax) {
                try Evaluator.evaluate(text: expression)
            }
        }

        @Test func tokenizerBasics() throws {
            let tokens = try ExpressionTokenizer.tokenize("2e3 + 2e × π − .5")
            #expect(tokens.count == 8)
            #expect(tokens[7].numberLiteral?.value == Numeric.value("0.5"))
            #expect(tokens[0].numberLiteral?.value == Numeric.value("2000"))
            if case .binary(.add) = tokens[1] {} else { Issue.record("expected +") }
            #expect(tokens[2].numberLiteral?.value == Numeric.value("2"))
            if case .constant(.e) = tokens[3] {} else { Issue.record("expected e") }
            if case .binary(.multiply) = tokens[4] {} else { Issue.record("expected ×") }
            if case .constant(.pi) = tokens[5] {} else { Issue.record("expected π") }
            if case .binary(.subtract) = tokens[6] {} else { Issue.record("expected −") }
        }

        @Test func previewPolicies() throws {
            let tokens = try ExpressionTokenizer.tokenize("2 + 3 *")
            #expect(throws: CalcError.syntax) { try PrattParser.parse(tokens, options: .strict) }
            let preview = try PrattParser.parse(tokens, options: .preview)
            #expect(try Evaluator().evaluate(preview).canonicalString() == "3E+0")
            let commit = try PrattParser.parse(tokens, options: .commit)
            #expect(try Evaluator().evaluate(commit).canonicalString() == "1.1E+1")
            let open = try ExpressionTokenizer.tokenize("(2 + 3 * 4")
            #expect(try Evaluator().evaluate(PrattParser.parse(open, options: .commit)).canonicalString() == "1.4E+1")
        }

        @Test func focusResolvesPercentInContext() throws {
            let tokens = try ExpressionTokenizer.tokenize("200 + 10%")
            let parsed = try PrattParser.parseWithFocus(tokens, focusEnd: tokens.count)
            let focus = try #require(parsed.focus)
            #expect(try Evaluator().evaluate(focus).canonicalString() == "2E+1")
            let mul = try ExpressionTokenizer.tokenize("50 * 10%")
            let parsedMul = try PrattParser.parseWithFocus(mul, focusEnd: mul.count)
            #expect(try Evaluator().evaluate(try #require(parsedMul.focus)).canonicalString() == "1E-1")
            let fn = try ExpressionTokenizer.tokenize("2 + sin(30)")
            let parsedFn = try PrattParser.parseWithFocus(fn, focusEnd: fn.count)
            #expect(try Evaluator().evaluate(try #require(parsedFn.focus)).canonicalString() == "5E-1")
        }

        @Test func lastBinaryCapture() throws {
            let tokens = try ExpressionTokenizer.tokenize("2 + 3 * 4")
            let parsed = try PrattParser.parseWithFocus(tokens, focusEnd: tokens.count, options: .commit)
            let last = try #require(parsed.lastBinary)
            #expect(last.op == .multiply)
            #expect(try Evaluator().evaluate(last.rhs).canonicalString() == "4E+0")
            let trailing = try ExpressionTokenizer.tokenize("2 * 3 +")
            let parsedTrailing = try PrattParser.parseWithFocus(trailing, focusEnd: trailing.count, options: .commit)
            let lastTrailing = try #require(parsedTrailing.lastBinary)
            #expect(lastTrailing.op == .add)
            #expect(try Evaluator().evaluate(lastTrailing.rhs).canonicalString() == "6E+0")
        }

        @Test func depthAndLengthLimits() throws {
            let deep = String(repeating: "(", count: 70) + "1" + String(repeating: ")", count: 70)
            #expect(throws: CalcError.tooComplex) { try Evaluator.evaluate(text: deep) }
            let long = Array(repeating: "1+", count: 300).joined() + "1"
            #expect(throws: CalcError.tooComplex) { try Evaluator.evaluate(text: long) }
        }
    }
}
