import SwiftUI
import CalcEngine

/// Toolbar above the display: mode (scientific / programmer / converter), cursor keys, backspace, settings.
/// Uses its own small glass container (siblings of the keypad container, never nested).
struct ModeBar: View {
    let snapshot: DisplaySnapshot
    let plan: LayoutPlan
    @Binding var showSettings: Bool

    @Environment(CalculatorModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 10) {
            if !plan.isCompactWidth {
                Menu {
                    Picker(selection: $model.mode) {
                        ForEach(CalculatorModel.Mode.allCases) { mode in
                            Label { Text(mode.titleKey, bundle: .main) } icon: { Image(systemName: mode.symbolName) }
                                .tag(mode)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.inline)
                } label: {
                    Label { Text(model.mode.titleKey, bundle: .main) } icon: { Image(systemName: model.mode.symbolName) }
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Text("modebar.mode", bundle: .main))
            }
            Spacer(minLength: 0)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    barButton("chevron.left", key: "modebar.cursorLeft") { model.send(.cursorLeft) }
                        .disabled(snapshot.cursor == 0 || snapshot.tokenCount == 0)
                    barButton("chevron.right", key: "modebar.cursorRight") { model.send(.cursorRight) }
                        .disabled(snapshot.cursor >= snapshot.tokenCount || snapshot.tokenCount == 0)
                    barButton("delete.left", key: "modebar.backspace") { model.send(.backspace) }
                        .disabled(snapshot.tokenCount == 0)
                    barButton("gearshape", key: "modebar.settings") { showSettings = true }
                }
            }
        }
        .controlSize(plan.isCompactWidth ? .small : .regular)
    }

    private func barButton(_ symbol: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(minWidth: 28, minHeight: 28)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text(LocalizedStringKey(key), bundle: .main))
    }
}
