import Testing
@testable import CalcEngine

extension CalcEngineTests {
    @Suite struct FormatterTests {
        static let fixture = try! Fixtures.load("formatting", as: FormattingFixture.self)

        @Test(arguments: Self.fixture.cases)
        func formatsLikeFixture(_ testCase: FormattingCase) throws {
            let value = try #require(CalcValue(literal: testCase.value))
            let formatter = DisplayFormatter(profile: testCase.profile == "compact" ? .compact : .regular,
                                             separators: .named(testCase.locale), usesGrouping: testCase.grouping)
            #expect(formatter.format(value) == testCase.expected)
        }

        @Test func entryEcho() {
            let f = DisplayFormatter()
            #expect(f.formatEntry(NumberLiteral(mantissa: "1234.50")) == "1,234.50")
            #expect(f.formatEntry(NumberLiteral(mantissa: "0.")) == "0.")
            #expect(f.formatEntry(NumberLiteral(mantissa: "2", exponent: "")) == "2e")
            #expect(f.formatEntry(NumberLiteral(mantissa: "2", exponent: "-3")) == "2e-3")
            #expect(f.formatEntry(NumberLiteral(mantissa: "5", isNegative: true)) == "-5")
            let de = DisplayFormatter(separators: .deDE)
            #expect(de.formatEntry(NumberLiteral(mantissa: "1234.5")) == "1.234,5")
        }

        @Test func expressionRendering() throws {
            let tokens = try ExpressionTokenizer.tokenize("2 + sin(30) × π − (3)² ^ 2")
            let text = ExpressionRenderer.text(tokens, formatter: .regularUS)
            #expect(text == "2 + sin(30) × π − (3)²^2")
            let negative = try ExpressionTokenizer.tokenize("-2 * -3")
            #expect(ExpressionRenderer.text(negative, formatter: .regularUS) == "−2 × −3")
            let segments = ExpressionRenderer.render(tokens, cursor: 2, formatter: .regularUS)
            #expect(segments.contains { $0.kind == .cursor })
            #expect(segments.filter { $0.kind == .cursor }.count == 1)
        }

        @Test func localeSeparatorsTable() {
            #expect(LocaleSeparators.named("es_MX").decimal == ".")
            #expect(LocaleSeparators.named("de_DE").decimal == ",")
            #expect(LocaleSeparators.named("de_DE").grouping == ".")
            #expect(LocaleSeparators.named("fr_FR").decimal == ",")
        }
    }
}
