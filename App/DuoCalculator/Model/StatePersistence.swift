import Foundation
import CalcEngine

/// Stores the whole `CalculatorState` (expression, cursor, memory, angle mode…) so a fold,
/// a background kill or a relaunch never loses the user's work.
enum StatePersistence {
    private static let key = "duo.calculator.state.v1"
    private static let programmerKey = "duo.programmer.state.v1"

    static func load() -> CalculatorState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CalculatorState.self, from: data)
    }

    static func save(_ state: CalculatorState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func loadProgrammer() -> ProgrammerEngine? {
        guard let data = UserDefaults.standard.data(forKey: programmerKey) else { return nil }
        return try? JSONDecoder().decode(ProgrammerEngine.self, from: data)
    }

    static func saveProgrammer(_ engine: ProgrammerEngine) {
        guard let data = try? JSONEncoder().encode(engine) else { return }
        UserDefaults.standard.set(data, forKey: programmerKey)
    }
}
