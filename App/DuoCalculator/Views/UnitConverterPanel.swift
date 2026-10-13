import SwiftUI
import CalcEngine

/// Unit converter. Exact arithmetic through the category's base unit.
struct UnitConverterPanel: View {
    /// `.panel`: a mode of the flat inner display; `.sheet`: opened from the mode menu of a compact layout (phones,
    /// the folded Duo), with the two cards stacked.
    enum Presentation { case panel, sheet }

    let plan: LayoutPlan
    var presentation: Presentation = .panel

    @Environment(CalculatorModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    private var formatter: DisplayFormatter { model.formatter }

    var body: some View {
        switch presentation {
        case .panel:
            content
                .padding(.horizontal, 20)
                .padding(.top, plan.displayTopInset)   // same clearance as the scientific mode bar: only occlusions over the top strip count
                .padding(.bottom, 16)
                .frame(width: plan.contentRect.width, height: plan.contentRect.height, alignment: .top)
                .offset(x: plan.contentRect.minX, y: plan.contentRect.minY)
        case .sheet:
            content
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
        }
    }

    private var content: some View {
        VStack(spacing: 14) {
            header
            categoryChips
            switch presentation {
            case .panel:
                HStack(alignment: .top, spacing: 12) {
                    fromCard
                    swapButton(symbol: "arrow.left.arrow.right")
                        .padding(.top, 48)
                    toCard
                }
            case .sheet:
                VStack(spacing: 8) {
                    fromCard
                    swapButton(symbol: "arrow.up.arrow.down")
                    toCard
                }
            }
            HStack {
                Button {
                    Task {
                        if let value = await model.currentValue() {
                            model.converter.inputText = formatter.format(value).replacingOccurrences(of: formatter.separators.grouping, with: "")
                        }
                    }
                } label: {
                    Label { Text("converter.useCalculatorValue", bundle: .main) } icon: { Image(systemName: "arrow.down.doc") }
                }
                .buttonStyle(.glass)
                Button {
                    if let value = model.converter.result(separators: formatter.separators) {
                        model.mode = .scientific
                        model.send(.recall(value))
                        if presentation == .sheet { dismiss() }
                    }
                } label: {
                    Label { Text("converter.sendToCalculator", bundle: .main) } icon: { Image(systemName: "function") }
                }
                .buttonStyle(.glass)
                .disabled(model.converter.result(separators: formatter.separators) == nil)
                Spacer()
            }
            table
        }
        .animation(Motion.digits, value: resultText)
    }

    private var fromCard: some View {
        @Bindable var model = model
        return card(titleKey: "converter.from") {
            unitPicker(selection: $model.converter.fromUnitID)
            TextField("", text: $model.converter.inputText, prompt: Text(verbatim: "0"))
                .keyboardType(.decimalPad)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .multilineTextAlignment(.trailing)
                .focused($inputFocused)
                .accessibilityLabel(Text("converter.inputValue", bundle: .main))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button { inputFocused = false } label: { Text("converter.done", bundle: .main) }
                    }
                }
        }
    }

    private var toCard: some View {
        @Bindable var model = model
        return card(titleKey: "converter.to") {
            unitPicker(selection: $model.converter.toUnitID)
            Text(verbatim: resultText)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentTransition(.numericText())
                .textSelection(.enabled)
                .accessibilityLabel(Text("converter.result", bundle: .main))
                .accessibilityValue(Text(verbatim: SpokenNumber.spoken(resultText)))
        }
    }

    private func swapButton(symbol: String) -> some View {
        Button {
            withAnimation(Motion.panel) { model.converter.swap() }
        } label: {
            Image(systemName: symbol)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text("converter.swap", bundle: .main))
    }

    private var resultText: String {
        guard let result = model.converter.result(separators: formatter.separators) else { return "—" }
        return formatter.format(result)
    }

    @ViewBuilder
    private var header: some View {
        @Bindable var model = model
        switch presentation {
        case .panel:
            HStack {
                Menu {
                    Picker(selection: $model.mode) {
                        ForEach(CalculatorModel.Mode.allCases) { mode in
                            Label { Text(mode.titleKey, bundle: .main) } icon: { Image(systemName: mode.symbolName) }.tag(mode)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.inline)
                } label: {
                    Label { Text(model.mode.titleKey, bundle: .main) } icon: { Image(systemName: model.mode.symbolName) }
                }
                .buttonStyle(.glass)
                Spacer()
                Text(model.converter.category.titleKey, bundle: .main)
                    .font(.title2.weight(.semibold))
            }
        case .sheet:
            HStack {
                Text(model.converter.category.titleKey, bundle: .main)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: { Text("converter.close", bundle: .main) }
                    .buttonStyle(.glass)
            }
        }
    }

    private var categoryChips: some View {
        @Bindable var model = model
        return ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(UnitCategory.allCases) { category in
                        Button {
                            withAnimation(Motion.panel) { model.converter.select(category) }
                        } label: {
                            Label { Text(category.titleKey, bundle: .main) } icon: { Image(systemName: category.symbolName) }
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.glass)
                        .tint(model.converter.category == category ? settings.accent.color : nil)
                        .accessibilityAddTraits(model.converter.category == category ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func card<Content: View>(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey, bundle: .main)
                .font(Typography.indicator())
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(GlassShapes.panel.fill(Color.primary.opacity(scheme == .dark ? 0.06 : 0.04)))
    }

    private func unitPicker(selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(UnitCatalog.units(in: model.converter.category)) { unit in
                (Text(verbatim: "\(unit.symbol) · ").foregroundStyle(.secondary) + Text(LocalizedStringKey(unit.nameKey), bundle: .main))
                    .tag(unit.id)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var table: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let value = model.converter.inputValue(separators: formatter.separators) {
                    ForEach(UnitConverter.table(value, from: model.converter.fromUnit), id: \.unit.id) { row in
                        HStack {
                            Text(LocalizedStringKey(row.unit.nameKey), bundle: .main)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(verbatim: row.value.map(formatter.format) ?? "—")
                                .font(.system(.body, design: .rounded).monospacedDigit())
                            Text(verbatim: row.unit.symbol)
                                .foregroundStyle(.tertiary)
                                .frame(width: 56, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }
}

extension UnitCategory {
    var titleKey: LocalizedStringKey {
        // Build the key as a String first: an interpolated literal would be coerced through
        // LocalizedStringKey's interpolation into the format key "unit.category.%@" (missing in the catalog).
        let key = "unit.category.\(rawValue)"
        return LocalizedStringKey(key)
    }
}
