import SwiftUI
import Observation
import CalcEngine

/// Main-actor façade over `CalculatorWorker`. Views read `snapshot`; keys call `press`/`send`.
@Observable
final class CalculatorModel {
    enum Mode: String, CaseIterable, Identifiable {
        case scientific, programmer, converter
        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .scientific: "mode.scientific"
            case .programmer: "mode.programmer"
            case .converter: "mode.converter"
            }
        }
        var symbolName: String {
            switch self {
            case .scientific: "function"
            case .programmer: "number"
            case .converter: "arrow.left.arrow.right"
            }
        }
    }

    private(set) var snapshot: DisplaySnapshot = .empty
    var mode: Mode = .scientific
    var programmer = ProgrammerEngine() {
        didSet { StatePersistence.saveProgrammer(programmer) }
    }
    var converter = ConverterState()

    /// Formatter derived from the layout (profile) and settings (grouping, locale).
    var displayProfile: DisplayProfile = .regular {
        didSet { if oldValue != displayProfile { refresh() } }
    }
    var usesGrouping = true {
        didSet { if oldValue != usesGrouping { refresh() } }
    }

    /// Bumped on every key press; drives `.sensoryFeedback`.
    private(set) var hapticTick = 0
    private(set) var lastHaptic: HapticKind = .light
    /// Bumped on `=` and on errors so the display can animate.
    private(set) var resultTick = 0

    @ObservationIgnored private let worker: CalculatorWorker
    @ObservationIgnored private var restored = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var inFlight = 0

    var isBusy: Bool { inFlight > 0 }

    init() {
        worker = CalculatorWorker()
        if let saved = StatePersistence.loadProgrammer() { programmer = saved }
    }

    var formatter: DisplayFormatter {
        DisplayFormatter(profile: displayProfile, separators: LocaleSeparators(locale: .current), usesGrouping: usesGrouping)
    }

    // MARK: Lifecycle

    func restoreIfNeeded() async {
        guard !restored else { return }
        restored = true
        if let saved = StatePersistence.load() {
            await worker.restore(saved)
        }
        snapshot = await worker.snapshot(formatter: formatter)
    }

    func refresh() {
        let formatter = formatter
        Task { snapshot = await worker.snapshot(formatter: formatter) }
    }

    // MARK: Input

    func press(_ key: KeyDefinition, second: Bool) {
        let action = (second ? key.secondAction : nil) ?? key.action
        lastHaptic = key.category.haptic
        hapticTick += 1
        perform(action)
    }

    func perform(_ action: KeyAction) {
        switch action {
        case .event(let event):
            send(event)
        case .toggleSecond:
            send(.toggleSecond)
        case .toggleAngle:
            send(.toggleAngleMode)
        case .none:
            break
        }
    }

    func send(_ event: CalculatorEvent) {
        let formatter = formatter
        inFlight += 1
        Task {
            let result = await worker.send(event, formatter: formatter)
            inFlight -= 1
            apply(result, after: event)
        }
    }

    /// `send` with the haptic of a physical key, for gestures that stand in for one (swipe ⌫, hardware keys).
    func send(_ event: CalculatorEvent, haptic: HapticKind) {
        lastHaptic = haptic
        hapticTick += 1
        send(event)
    }

    private func apply(_ result: DisplaySnapshot, after event: CalculatorEvent) {
        let wasError = snapshot.isError
        snapshot = result
        if result.isError && !wasError {
            lastHaptic = .error
            hapticTick += 1
            resultTick += 1
        } else if case .equals = event {
            lastHaptic = .success
            hapticTick += 1
            resultTick += 1
        }
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let state = await worker.state()
            StatePersistence.save(state)
        }
    }

    func saveNow() {
        Task {
            let state = await worker.state()
            StatePersistence.save(state)
        }
    }

    /// Current display value, e.g. to feed the unit converter or copy to the pasteboard.
    func currentValue() async -> CalcValue? {
        await worker.currentValue()
    }

    // MARK: Hardware keyboard

    func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard let event = KeyboardMapping.event(for: press) else { return .ignored }
        send(event, haptic: .light)
        return .handled
    }
}

/// State of the unit converter panel.
struct ConverterState: Equatable {
    var category: UnitCategory = .length
    var fromUnitID: String = UnitCatalog.defaultPair(for: .length).from.id
    var toUnitID: String = UnitCatalog.defaultPair(for: .length).to.id
    var inputText: String = "1"

    var fromUnit: UnitDefinition { UnitCatalog.unit(id: fromUnitID) ?? UnitCatalog.defaultPair(for: category).from }
    var toUnit: UnitDefinition { UnitCatalog.unit(id: toUnitID) ?? UnitCatalog.defaultPair(for: category).to }

    mutating func select(_ newCategory: UnitCategory) {
        guard newCategory != category else { return }
        category = newCategory
        let pair = UnitCatalog.defaultPair(for: newCategory)
        fromUnitID = pair.from.id
        toUnitID = pair.to.id
    }

    mutating func swap() {
        (fromUnitID, toUnitID) = (toUnitID, fromUnitID)
    }

    var inputValue: CalcValue? {
        CalcValue(literal: inputText.replacingOccurrences(of: ",", with: ""))
    }

    func result() -> CalcValue? {
        guard let value = inputValue else { return nil }
        return try? UnitConverter.convert(value, from: fromUnit, to: toUnit)
    }
}

enum HapticKind: Hashable {
    case light, medium, heavy, selection, success, error, soft
}

/// Hardware keyboard → events.
enum KeyboardMapping {
    static func event(for press: KeyPress) -> CalculatorEvent? {
        if press.modifiers.contains(.command) {
            switch press.characters {
            case "c", "v": return nil   // copy / paste handled by the display
            default: return nil
            }
        }
        switch press.key {
        case .return: return .equals
        case .delete: return .backspace
        case .escape: return .allClear
        case .leftArrow: return .cursorLeft
        case .rightArrow: return .cursorRight
        case .home: return .cursorToStart
        case .end: return .cursorToEnd
        default: break
        }
        switch press.characters {
        case "0"..."9": return .digit(Int(press.characters)!)
        case ".", ",": return .decimalSeparator
        case "+": return .binary(.add)
        case "-", "−": return .binary(.subtract)
        case "*", "x", "×": return .binary(.multiply)
        case "/", "÷": return .binary(.divide)
        case "^": return .binary(.power)
        case "%": return .percent
        case "!": return .postfix(.factorial)
        case "(": return .openParen
        case ")": return .closeParen
        case "=": return .equals
        case "p": return .constant(.pi)
        case "e": return .constant(.e)
        case "r": return .function(.sqrt)
        case "s": return .function(.sin)
        case "o": return .function(.cos)
        case "t": return .function(.tan)
        case "l": return .function(.ln)
        case "n": return .toggleSign
        default: return nil
        }
    }
}
