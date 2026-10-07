import Foundation
import CalcEngine

/// Owns the engine off the main actor and serialises every evaluation
/// (BigDecimal keeps global caches, so exactly one actor may touch `MathKernel`).
actor CalculatorWorker {
    private var engine: CalculatorEngine

    init(state: CalculatorState = CalculatorState()) {
        engine = CalculatorEngine(state: state)
    }

    func send(_ event: CalculatorEvent, formatter: DisplayFormatter) -> DisplaySnapshot {
        engine.send(event)
        return engine.snapshot(formatter: formatter)
    }

    func snapshot(formatter: DisplayFormatter) -> DisplaySnapshot {
        engine.snapshot(formatter: formatter)
    }

    func currentValue() -> CalcValue? {
        engine.currentValue()
    }

    func state() -> CalculatorState {
        engine.state
    }

    func restore(_ state: CalculatorState) {
        engine.state = state
    }
}
