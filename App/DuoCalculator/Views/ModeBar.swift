import SwiftUI
import CalcEngine

/// Toolbar above the display: mode, History, cursor keys, backspace, settings. On the inner display the mode menu
/// switches scientific / programmer / converter in place; compact layouts (phones, the folded Duo) offer Basic /
/// Scientific where the other arrangement fits and open the converter as a sheet. Narrow displays fold History and
/// Settings into a menu first, then drop the menu title, and drop the cursor keys (the only button route to
/// mid-expression editing) last.
/// Uses its own small glass container (siblings of the keypad container, never nested).
struct ModeBar: View {
    let snapshot: DisplaySnapshot
    let plan: LayoutPlan
    @Binding var sheet: RootSheet?

    @Environment(CalculatorModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(titled: true, cursorKeys: true, collapsed: false)
            bar(titled: true, cursorKeys: true, collapsed: true)
            bar(titled: false, cursorKeys: true, collapsed: true)
            bar(titled: false, cursorKeys: false, collapsed: true)
        }
        .controlSize(plan.isCompactWidth ? .small : .regular)
    }

    private func bar(titled: Bool, cursorKeys: Bool, collapsed: Bool) -> some View {
        HStack(spacing: 10) {
            modeMenu(titled: titled)
            Spacer(minLength: 0)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if !collapsed {
                        barButton("clock.arrow.circlepath", key: "modebar.history") { sheet = .history }
                    }
                    if cursorKeys {
                        barButton("chevron.left", key: "modebar.cursorLeft") { model.send(.cursorLeft) }
                            .disabled(snapshot.cursor == 0 || snapshot.tokenCount == 0)
                        barButton("chevron.right", key: "modebar.cursorRight") { model.send(.cursorRight) }
                            .disabled(snapshot.cursor >= snapshot.tokenCount || snapshot.tokenCount == 0)
                    }
                    barButton("delete.left", key: "modebar.backspace") { model.send(.backspace) }
                        .disabled(snapshot.tokenCount == 0)
                    if collapsed {
                        moreMenu
                    } else {
                        barButton("gearshape", key: "modebar.settings") { sheet = .settings }
                    }
                }
            }
        }
    }

    // MARK: Mode

    @ViewBuilder
    private func modeMenu(titled: Bool) -> some View {
        @Bindable var model = model
        if plan.panelsAvailable {
            Menu {
                Picker(selection: $model.mode) {
                    ForEach(CalculatorModel.Mode.allCases) { mode in
                        Label { Text(mode.titleKey, bundle: .main) } icon: { Image(systemName: mode.symbolName) }
                            .tag(mode)
                    }
                } label: { EmptyView() }
                .pickerStyle(.inline)
            } label: {
                modeLabel(titleKey: model.mode.titleKey, symbol: model.mode.symbolName, titled: titled)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Text("modebar.mode", bundle: .main))
            .accessibilityValue(Text(model.mode.titleKey, bundle: .main))
            .accessibilityIdentifier("modebar.mode")
        } else if plan.isCompactWidth {
            Menu {
                if let toggle = plan.scientificToggle {
                    Picker(selection: scientificBinding(toggle)) {
                        Label { Text("mode.basic", bundle: .main) } icon: { Image(systemName: Self.basicSymbol) }
                            .tag(false)
                        Label { Text("mode.scientific", bundle: .main) } icon: { Image(systemName: Self.scientificSymbol) }
                            .tag(true)
                    } label: { EmptyView() }
                    .pickerStyle(.inline)
                }
                Button { sheet = .converter } label: {
                    Label { Text("mode.converter", bundle: .main) } icon: { Image(systemName: CalculatorModel.Mode.converter.symbolName) }
                }
            } label: {
                modeLabel(titleKey: plan.mode.isScientific ? "mode.scientific" : "mode.basic",
                          symbol: plan.mode.isScientific ? Self.scientificSymbol : Self.basicSymbol, titled: titled)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(Text("modebar.mode", bundle: .main))
            .accessibilityValue(Text(plan.mode.isScientific ? "mode.scientific" : "mode.basic", bundle: .main))
            .accessibilityIdentifier("modebar.mode")
        }
    }

    private static let basicSymbol = "plus.forwardslash.minus"
    private static let scientificSymbol = "function"

    @ViewBuilder
    private func modeLabel(titleKey: LocalizedStringKey, symbol: String, titled: Bool) -> some View {
        let label = Label { Text(titleKey, bundle: .main) } icon: { Image(systemName: symbol) }
        if titled {
            label.labelStyle(.titleAndIcon)
        } else {
            label.labelStyle(.iconOnly).frame(minWidth: 28, minHeight: 28)
        }
    }

    /// Basic/Scientific is remembered per orientation, like the iPhone convention of turning the phone for scientific.
    private func scientificBinding(_ toggle: ScientificToggle) -> Binding<Bool> {
        Binding(
            get: { plan.mode.isScientific },
            set: { scientific in
                switch toggle {
                case .portrait: settings.scientificInCompactPortrait = scientific
                case .landscape: settings.scientificInFoldedLandscape = scientific
                }
            })
    }

    // MARK: Buttons

    private var moreMenu: some View {
        Menu {
            Button { sheet = .history } label: {
                Label { Text("modebar.history", bundle: .main) } icon: { Image(systemName: "clock.arrow.circlepath") }
            }
            Button { sheet = .settings } label: {
                Label { Text("modebar.settings", bundle: .main) } icon: { Image(systemName: "gearshape") }
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(minWidth: 28, minHeight: 28)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text("modebar.more", bundle: .main))
        .accessibilityIdentifier("modebar.more")
    }

    private func barButton(_ symbol: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(minWidth: 28, minHeight: 28)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text(LocalizedStringKey(key), bundle: .main))
        .accessibilityIdentifier(key)
    }
}
