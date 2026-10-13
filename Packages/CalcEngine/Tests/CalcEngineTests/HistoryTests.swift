import Foundation
import Testing
@testable import CalcEngine

extension CalcEngineTests {
    /// The calculation history behind the History panel: one entry per committed `=`.
    @Suite struct HistoryTests {
        struct FixedDateSource: DateSource {
            var date: Date
            func now() -> Date { date }
        }

        static let fixedDate = Date(timeIntervalSince1970: 1_790_000_000)

        static func engine() -> CalculatorEngine {
            CalculatorEngine(random: SeededRandomSource(seed: 7), clock: FixedDateSource(date: fixedDate))
        }

        static func send(_ events: [CalculatorEvent], to engine: inout CalculatorEngine) {
            for event in events { engine.send(event) }
        }

        @Test func equalsRecordsTheCommittedExpression() throws {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals], to: &engine)
            let entry = try #require(engine.state.history.last)
            #expect(engine.state.history.count == 1)
            #expect(entry.result == CalcValue(5))
            #expect(entry.tokens == engine.state.committedTokens)
            #expect(entry.date == Self.fixedDate)
        }

        @Test func plainNumberEqualsIsNotRecorded() {
            var engine = Self.engine()
            Self.send([.digit(5), .equals], to: &engine)
            #expect(engine.state.history.isEmpty)
        }

        @Test func functionEqualsIsRecorded() throws {
            var engine = Self.engine()
            Self.send([.digit(3), .digit(0), .function(.sin), .equals], to: &engine)
            let entry = try #require(engine.state.history.last)
            #expect(entry.result == CalcValue(literal: "0.5"))
        }

        @Test func equalsWithoutRepeatOperationAddsNothing() {
            var engine = Self.engine()
            Self.send([.digit(3), .digit(0), .function(.sin), .equals], to: &engine)
            #expect(engine.state.history.count == 1)
            engine.send(.equals)
            #expect(engine.state.history.count == 1)
        }

        @Test func repeatedEqualsRecordsEveryStep() {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals, .equals, .equals], to: &engine)
            #expect(engine.state.history.map(\.result) == [CalcValue(5), CalcValue(8), CalcValue(11)])
        }

        @Test func errorsAreNotRecorded() {
            var engine = Self.engine()
            Self.send([.digit(1), .binary(.divide), .digit(0), .equals], to: &engine)
            #expect(engine.state.isError)
            #expect(engine.state.history.isEmpty)
        }

        @Test func historyIsCapped() {
            var engine = Self.engine()
            Self.send([.digit(1), .binary(.add), .digit(1), .equals], to: &engine)
            for _ in 0..<(CalculatorState.maxHistoryEntries + 5) { engine.send(.equals) }
            #expect(engine.state.history.count == CalculatorState.maxHistoryEntries)
            // 1 + 1 = 2, then +1 per repeat: the oldest entries were dropped, the newest kept.
            #expect(engine.state.history.last?.result == CalcValue(CalculatorState.maxHistoryEntries + 7))
        }

        @Test func clearHistoryKeepsTheDisplay() {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals], to: &engine)
            engine.send(.clearHistory)
            #expect(engine.state.history.isEmpty)
            #expect(engine.snapshot(formatter: .regularUS).primary == "5")
        }

        @Test func clearHistoryWorksInTheErrorPhase() {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals], to: &engine)
            Self.send([.digit(1), .binary(.divide), .digit(0), .equals], to: &engine)
            #expect(engine.state.isError)
            engine.send(.clearHistory)
            #expect(engine.state.history.isEmpty)
            #expect(engine.state.isError)
        }

        @Test func deleteRemovesOnlyThatEntry() throws {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals, .equals, .equals], to: &engine)
            let middle = try #require(engine.state.history.dropFirst().first)
            engine.send(.deleteHistoryEntry(middle.id))
            #expect(engine.state.history.map(\.result) == [CalcValue(5), CalcValue(11)])
        }

        @Test func recallReplacesTheNumberBeingTyped() {
            var engine = Self.engine()
            Self.send([.digit(2), .recall(CalcValue(5))], to: &engine)
            #expect(engine.snapshot(formatter: .regularUS).primary == "5")
            Self.send([.binary(.multiply), .digit(2), .equals], to: &engine)
            #expect(engine.state.lastResult == CalcValue(10))
        }

        @Test func recallAfterAnOperatorIsTheNextOperand() {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .recall(CalcValue(5)), .equals], to: &engine)
            #expect(engine.state.lastResult == CalcValue(7))
        }

        @Test func recallAfterAResultStartsANewExpression() {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals, .recall(CalcValue(10))], to: &engine)
            #expect(engine.snapshot(formatter: .regularUS).primary == "10")
            Self.send([.binary(.add), .digit(1), .equals], to: &engine)
            #expect(engine.state.lastResult == CalcValue(11))
        }

        @Test func longExpressionsKeepOnlyTheirResult() throws {
            var engine = Self.engine()
            for _ in 0..<40 { Self.send([.digit(1), .binary(.add)], to: &engine) }
            Self.send([.digit(1), .equals], to: &engine)
            let entry = try #require(engine.state.history.last)
            #expect(entry.tokens.isEmpty)
            #expect(entry.result == CalcValue(41))
            #expect(try JSONEncoder().encode(entry).count <= HistoryEntry.maxEncodedBytes)
        }

        @Test func hugeExactResultsStayWithinTheEntryBudget() throws {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.power), .digit(3), .digit(0), .digit(0), .digit(0), .equals], to: &engine)
            let entry = try #require(engine.state.history.last)
            let computed = try #require(engine.state.lastResult)
            #expect(try JSONEncoder().encode(entry).count <= HistoryEntry.maxEncodedBytes)
            #expect(entry.result.approx == computed.approx)
        }

        @Test func rowsAreNewestFirstAndFormattedLikeTheDisplay() throws {
            var engine = Self.engine()
            Self.send([.digit(1), .digit(2), .decimalSeparator, .digit(5), .binary(.multiply), .digit(2), .equals], to: &engine)
            Self.send([.digit(7), .binary(.add), .digit(1), .equals], to: &engine)
            for _ in 0..<40 { Self.send([.digit(1), .binary(.add)], to: &engine) }
            Self.send([.digit(1), .equals], to: &engine)
            let mexican = DisplayFormatter(profile: .regular, separators: .named("es_MX"), usesGrouping: true)
            let rows = engine.historyRows(formatter: mexican)
            #expect(rows.map(\.result) == ["41", "8", "25"])
            #expect(rows[0].expression == nil)
            #expect(rows[1].expression == "7 + 1")
            #expect(rows[2].expression == ExpressionRenderer.text(engine.state.history[0].tokens, formatter: mexican))
            #expect(rows.map(\.id) == engine.state.history.reversed().map(\.id))
        }

        @Test func historySurvivesCoding() throws {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals], to: &engine)
            let data = try JSONEncoder().encode(engine.state)
            let decoded = try JSONDecoder().decode(CalculatorState.self, from: data)
            #expect(decoded == engine.state)
        }

        @Test func stateSavedBeforeHistoryStillDecodes() throws {
            var engine = Self.engine()
            Self.send([.digit(2), .binary(.add), .digit(3), .equals], to: &engine)
            var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(engine.state)) as? [String: Any])
            object.removeValue(forKey: "history")
            object["results"] = []
            let legacy = try JSONSerialization.data(withJSONObject: object)
            let decoded = try JSONDecoder().decode(CalculatorState.self, from: legacy)
            #expect(decoded.history.isEmpty)
            #expect(decoded.lastResult == CalcValue(5))
        }
    }
}
