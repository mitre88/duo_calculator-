import SwiftUI
import CalcEngine

/// Programmer mode (inner display only): value in HEX / DEC / OCT / BIN, 64-bit grid and an integer keypad.
struct ProgrammerPanel: View {
    let plan: LayoutPlan

    @Environment(CalculatorModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    private struct Key: Identifiable {
        enum Kind { case digit(Int), op(ProgrammerOperator), unary(ProgrammerUnary), equals, clear, backspace }
        let id: String
        let label: String
        let kind: Kind
        var category: KeyCategory = .function
        var span: Int = 1
    }

    private var rows: [[Key]] {
        [
            [Key(id: "and", label: "AND", kind: .op(.and)), Key(id: "or", label: "OR", kind: .op(.or)),
             Key(id: "xor", label: "XOR", kind: .op(.xor)), Key(id: "nor", label: "NOR", kind: .op(.nor)),
             Key(id: "ac", label: "AC", kind: .clear, category: .utility), Key(id: "back", label: "⌫", kind: .backspace, category: .utility),
             Key(id: "neg", label: "±", kind: .unary(.negate), category: .utility), Key(id: "div", label: "÷", kind: .op(.divide), category: .binaryOperator)],
            [Key(id: "not", label: "NOT", kind: .unary(.not)), Key(id: "shl", label: "<<", kind: .op(.shiftLeft)),
             Key(id: "shr", label: ">>", kind: .op(.shiftRight)), Key(id: "mod", label: "mod", kind: .op(.modulo)),
             Key(id: "d", label: "D", kind: .digit(13), category: .digit), Key(id: "e", label: "E", kind: .digit(14), category: .digit),
             Key(id: "f", label: "F", kind: .digit(15), category: .digit), Key(id: "mul", label: "×", kind: .op(.multiply), category: .binaryOperator)],
            [Key(id: "rol", label: "RoL", kind: .unary(.rotateLeft)), Key(id: "ror", label: "RoR", kind: .unary(.rotateRight)),
             Key(id: "ones", label: "1's", kind: .unary(.onesComplement)), Key(id: "twos", label: "2's", kind: .unary(.twosComplement)),
             Key(id: "a", label: "A", kind: .digit(10), category: .digit), Key(id: "b", label: "B", kind: .digit(11), category: .digit),
             Key(id: "c", label: "C", kind: .digit(12), category: .digit), Key(id: "sub", label: "−", kind: .op(.subtract), category: .binaryOperator)],
            [Key(id: "shl1", label: "<<1", kind: .unary(.shiftLeftOne)), Key(id: "shr1", label: ">>1", kind: .unary(.shiftRightOne)),
             Key(id: "byte", label: "byte", kind: .unary(.byteFlip)), Key(id: "word", label: "word", kind: .unary(.wordFlip)),
             Key(id: "7", label: "7", kind: .digit(7), category: .digit), Key(id: "8", label: "8", kind: .digit(8), category: .digit),
             Key(id: "9", label: "9", kind: .digit(9), category: .digit), Key(id: "add", label: "+", kind: .op(.add), category: .binaryOperator)],
            [Key(id: "4", label: "4", kind: .digit(4), category: .digit), Key(id: "5", label: "5", kind: .digit(5), category: .digit),
             Key(id: "6", label: "6", kind: .digit(6), category: .digit), Key(id: "1", label: "1", kind: .digit(1), category: .digit),
             Key(id: "2", label: "2", kind: .digit(2), category: .digit), Key(id: "3", label: "3", kind: .digit(3), category: .digit),
             Key(id: "0", label: "0", kind: .digit(0), category: .digit), Key(id: "eq", label: "=", kind: .equals, category: .equals)],
        ]
    }

    var body: some View {
        @Bindable var model = model
        let engine = model.programmer
        VStack(spacing: 10) {
            header(engine: engine)
            display(engine: engine)
            BitGridView(value: engine.value) { index in
                model.programmer.send(.toggleBit(index))
            }
            .padding(.horizontal, 4)
            keypad(engine: engine)
        }
        .padding(.horizontal, 20)
        .padding(.top, plan.displayTopInset)   // same clearance as the scientific mode bar: only occlusions over the top strip count
        .padding(.bottom, 16)
        .frame(width: plan.contentRect.width, height: plan.contentRect.height, alignment: .top)
        .offset(x: plan.contentRect.minX, y: plan.contentRect.minY)
    }

    private func header(engine: ProgrammerEngine) -> some View {
        @Bindable var model = model
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
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

                Spacer(minLength: 0)

                Toggle(isOn: Binding(get: { engine.isSigned }, set: { _ in model.programmer.send(.toggleSigned) })) {
                    Text("programmer.signed", bundle: .main)
                }
                .toggleStyle(.button)
                .buttonStyle(.glass)

                Button {
                    let value = engine.value.calcValue
                    model.mode = .scientific
                    model.send(.recall(value))
                } label: {
                    Label { Text("programmer.sendToCalculator", bundle: .main) } icon: { Image(systemName: "function") }
                }
                .buttonStyle(.glass)
            }

            HStack(spacing: 12) {
                Picker("", selection: Binding(get: { engine.radix }, set: { model.programmer.send(.setRadix($0)) })) {
                    ForEach(Radix.allCases) { radix in Text(verbatim: radix.label).tag(radix) }
                }
                .pickerStyle(.segmented)

                Picker("", selection: Binding(get: { engine.width }, set: { model.programmer.send(.setWidth($0)) })) {
                    ForEach(BitWidth.allCases) { width in Text(verbatim: "\(width.rawValue)").tag(width) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }
        }
        .font(.subheadline)
    }

    private func display(engine: ProgrammerEngine) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(verbatim: engine.primaryText)
                .font(.system(size: 56, weight: .light, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .foregroundStyle(engine.isError ? Palette.error : Color.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentTransition(.numericText())
                .accessibilityLabel(Text("display.result", bundle: .main))
                .accessibilityValue(Text(verbatim: engine.primaryText))
            ForEach(engine.conversions, id: \.radix) { conversion in
                HStack {
                    Text(verbatim: conversion.radix.label)
                        .font(Typography.indicator())
                        .foregroundStyle(conversion.radix == engine.radix ? Color.accentColor : Color.secondary)
                        .frame(width: 44, alignment: .leading)
                    Spacer()
                    Text(verbatim: conversion.text)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.secondary)
                }
            }
            if let character = engine.value.characterDescription {
                Text(verbatim: "'\(character)'")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GlassShapes.panel.fill(Color.primary.opacity(scheme == .dark ? 0.06 : 0.04)))
        .animation(Motion.digits, value: engine.primaryText)
    }

    private static let keyRowSpacing: CGFloat = 6
    private static let keyHeightRange: ClosedRange<CGFloat> = 44...64

    private func keypad(engine: ProgrammerEngine) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
        let rowCount = CGFloat(rows.count)
        let gaps = (rowCount - 1) * Self.keyRowSpacing
        return GeometryReader { proxy in
            // Rows share whatever height the header, display and bit grid leave, within 44…64 pt.
            let fitted = (proxy.size.height - gaps) / rowCount
            let keyHeight = min(Self.keyHeightRange.upperBound, max(Self.keyHeightRange.lowerBound, fitted))
            keyGrid(engine: engine, columns: columns, keyHeight: keyHeight)
        }
        .frame(minHeight: rowCount * Self.keyHeightRange.lowerBound + gaps)
    }

    private func keyGrid(engine: ProgrammerEngine, columns: [GridItem], keyHeight: CGFloat) -> some View {
        GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: columns, spacing: Self.keyRowSpacing) {
                ForEach(rows.flatMap { $0 }) { key in
                    let enabled = isEnabled(key, radix: engine.radix)
                    let active = isActive(key, engine: engine)
                    Button {
                        press(key)
                    } label: {
                        Text(verbatim: key.label)
                            .font(key.category == .digit ? Typography.digitKey(keyHeight: keyHeight) : Typography.functionKey(keyHeight: keyHeight))
                            .frame(maxWidth: .infinity, minHeight: keyHeight, maxHeight: keyHeight)
                            .foregroundStyle(labelColor(key, active: active))
                    }
                    .buttonStyle(KeyPressStyle())
                    .keyGlass(category: key.category, isActive: active,
                              shape: AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous)),
                              accent: settings.accent.color)
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.35)
                    .accessibilityLabel(Text(verbatim: key.label))
                }
            }
        }
    }

    private func isEnabled(_ key: Key, radix: Radix) -> Bool {
        if case .digit(let d) = key.kind { return d < radix.rawValue }
        return true
    }

    private func isActive(_ key: Key, engine: ProgrammerEngine) -> Bool {
        if case .op(let op) = key.kind { return engine.pendingOperator == op && engine.isAwaitingOperand }
        return false
    }

    /// Same rule as `KeyFaceView`: the active key is a light pill, so its label must turn dark (or accent).
    private func labelColor(_ key: Key, active: Bool) -> Color {
        let isOperator = key.category == .binaryOperator || key.category == .equals
        if active { return isOperator ? settings.accent.color : .black }
        return isOperator ? .white : .primary
    }

    private func press(_ key: Key) {
        switch key.kind {
        case .digit(let d): model.programmer.send(.digit(d))
        case .op(let op): model.programmer.send(.binary(op))
        case .unary(let op): model.programmer.send(.unary(op))
        case .equals: model.programmer.send(.equals)
        case .clear: model.programmer.send(engine_hasEntry ? .clear : .allClear)
        case .backspace: model.programmer.send(.backspace)
        }
    }

    private var engine_hasEntry: Bool { model.programmer.hasEntry }
}
