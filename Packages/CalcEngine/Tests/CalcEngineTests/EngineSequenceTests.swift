import Foundation
import Testing
@testable import CalcEngine

extension CalcEngineTests {
    /// Key sequences with the display they must produce (`ios_sequences.json`).
    @Suite struct EngineSequenceTests {
        static let fixture = try! Fixtures.load("ios_sequences", as: SequenceFixture.self)

        static func formatter(for fixture: SequenceFixture) -> DisplayFormatter {
            DisplayFormatter(profile: fixture.profile == "compact" ? .compact : .regular,
                             separators: .named(fixture.locale), usesGrouping: true)
        }

        @Test(arguments: fixture.cases)
        func producesExpectedDisplay(_ testCase: SequenceCase) throws {
            var engine = CalculatorEngine(random: SeededRandomSource(seed: 42))
            engine.send(.setAngleMode(Numeric.angle(Self.fixture.angle)))
            for key in testCase.keys {
                let event = try #require(CalculatorEvent(testName: key), "unknown key \(key)")
                engine.send(event)
            }
            let snapshot = engine.snapshot(formatter: Self.formatter(for: Self.fixture))
            #expect(snapshot.primary == testCase.primary, "\(testCase.id): expression=\(snapshot.expressionText)")
            if let expression = testCase.expression {
                #expect(snapshot.expressionText == expression, testCase.id)
            }
        }

        @Test func clearLabelFollowsEntry() {
            var engine = CalculatorEngine()
            #expect(engine.snapshot(formatter: .regularUS).clearLabel == .allClear)
            engine.send(.digit(5))
            #expect(engine.snapshot(formatter: .regularUS).clearLabel == .clear)
            engine.send(.binary(.add))
            #expect(engine.snapshot(formatter: .regularUS).clearLabel == .allClear)
            #expect(engine.snapshot(formatter: .regularUS).pendingOperator == .add)
        }

        @Test func previewLineShowsLiveResult() {
            var engine = CalculatorEngine()
            for e in [CalculatorEvent.digit(1), .digit(2), .binary(.add), .digit(3)] { engine.send(e) }
            let snapshot = engine.snapshot(formatter: .regularUS)
            #expect(snapshot.primary == "3")
            #expect(snapshot.preview == "15")
            engine.send(.equals)
            let result = engine.snapshot(formatter: .regularUS)
            #expect(result.primary == "15")
            #expect(result.preview == nil)
            #expect(result.showsResult)
        }

        @Test func randomInsertsSixteenDigitUnitValue() {
            var engine = CalculatorEngine(random: SeededRandomSource(seed: 7))
            engine.send(.random)
            let value = engine.currentValue()
            #expect(value != nil)
            #expect(value! >= .zero && value! < .one)
            #expect(engine.snapshot(formatter: .regularUS).primary.hasPrefix("0."))
        }

        @Test func compactProfileShortensDisplay() {
            var engine = CalculatorEngine()
            engine.send(.constant(.pi))
            let compact = DisplayFormatter(profile: .compact)
            #expect(engine.snapshot(formatter: compact).primary == "3.14159265359")
            #expect(engine.snapshot(formatter: .regularUS).primary == "3.141592653589793")
        }

        @Test func pasteInsertsTokens() {
            var engine = CalculatorEngine()
            engine.send(.insertText("2^10 + sin(30)"))
            engine.send(.equals)
            #expect(engine.snapshot(formatter: .regularUS).primary == "1,024.5")
        }

        @Test func cursorTapPlacement() {
            var engine = CalculatorEngine()
            for e in [CalculatorEvent.digit(1), .binary(.add), .digit(2), .binary(.multiply), .digit(3)] { engine.send(e) }
            engine.send(.cursorTo(1))   // right after "1"
            engine.send(.digit(0))
            engine.send(.equals)
            #expect(engine.snapshot(formatter: .regularUS).primary == "16")  // 10 + 2 × 3
        }

        @Test func approxLaneSurvivesResultReuse() {
            var engine = CalculatorEngine()
            for e in [CalculatorEvent.digit(2), .function(.sqrt), .equals, .postfix(.square), .binary(.subtract), .digit(2), .equals] {
                engine.send(e)
            }
            #expect(engine.snapshot(formatter: .regularUS).primary == "0")
        }

        @Test func stateCodableRoundTrip() throws {
            var engine = CalculatorEngine()
            for e in [CalculatorEvent.digit(7), .binary(.multiply), .digit(6), .equals, .memory(.add), .setAngleMode(.radians)] {
                engine.send(e)
            }
            let data = try JSONEncoder().encode(engine.state)
            let restored = try JSONDecoder().decode(CalculatorState.self, from: data)
            #expect(restored == engine.state)
            let restoredEngine = CalculatorEngine(state: restored)
            #expect(restoredEngine.snapshot(formatter: .regularUS).primary == "42")
            #expect(restoredEngine.snapshot(formatter: .regularUS).memoryActive)
            #expect(restoredEngine.snapshot(formatter: .regularUS).angleMode == .radians)
        }
    }
}
