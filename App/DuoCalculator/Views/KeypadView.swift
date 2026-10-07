import SwiftUI
import CalcEngine

/// One keypad = one grid of `KeyButton`s. The same view type renders the basic and the scientific
/// arrangement, so SwiftUI keeps per-key identity and animates each key to its new cell.
struct KeypadView: View {
    let spec: KeyGridSpec
    let plan: LayoutPlan
    let namespace: Namespace.ID

    @Environment(CalculatorModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let snapshot = model.snapshot
        KeyGridLayout(spec: spec, spacing: plan.keySpacing, centerGutter: plan.centerGutter, keySize: plan.keySize) {
            ForEach(spec.placements, id: \.key) { placement in
                let definition = KeyCatalog.definition(placement.key)
                KeyButton(
                    definition: definition,
                    showsSecondFace: snapshot.isSecondActive,
                    isActive: isActive(definition, snapshot: snapshot),
                    shape: placement.columnSpan > 1 ? .roundedRectangle : plan.keyShape,
                    keySize: plan.keySize,
                    accent: settings.accent.color,
                    labelOverride: labelOverride(definition, snapshot: snapshot),
                    namespace: namespace,
                    onPress: { model.press(definition, second: snapshot.isSecondActive) })
                .keyPlacement(placement)
                .transition(Motion.keyTransition(row: placement.row, column: placement.column, columns: spec.columns,
                                                 gutterAfterColumn: spec.gutterAfterColumn, reduceMotion: reduceMotion))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(LocalizedStringKey("keypad." + spec.name), bundle: .main))
    }

    private func isActive(_ definition: KeyDefinition, snapshot: DisplaySnapshot) -> Bool {
        switch definition.id {
        case .add: snapshot.pendingOperator == .add
        case .subtract: snapshot.pendingOperator == .subtract
        case .multiply: snapshot.pendingOperator == .multiply
        case .divide: snapshot.pendingOperator == .divide
        case .power: snapshot.pendingOperator == .power
        case .nthRoot: snapshot.pendingOperator == .root
        case .second: snapshot.isSecondActive
        case .angleMode: snapshot.angleMode == .radians
        case .memoryRecall: snapshot.memoryActive
        default: false
        }
    }

    private func labelOverride(_ definition: KeyDefinition, snapshot: DisplaySnapshot) -> String? {
        switch definition.id {
        case .allClear: snapshot.clearLabel.rawValue
        case .angleMode: snapshot.angleMode == .degrees ? "Rad" : "Deg"
        default: nil
        }
    }
}
