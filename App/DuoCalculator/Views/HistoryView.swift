import SwiftUI
import CalcEngine

/// History as a sheet: phones, the folded Duo and every compact layout.
struct HistorySheet: View {
    @Environment(CalculatorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            HistoryList { dismiss() }
                .navigationTitle(Text("history.title", bundle: .main))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .destructive) { confirmClear = true } label: { Text("history.clear", bundle: .main) }
                            .disabled(model.history.isEmpty)
                            .accessibilityIdentifier("history.clear")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: { Text("history.done", bundle: .main) }
                            .accessibilityIdentifier("history.done")
                    }
                }
                .clearHistoryConfirmation(isPresented: $confirmClear)
        }
        .presentationDetents([.medium, .large])
    }
}

/// History as a panel inside the inner display, at the frame `LayoutResolver.historyFrame` keeps clear of the fold.
struct HistoryPanel: View {
    let close: () -> Void

    @Environment(CalculatorModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("history.title", bundle: .main)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(role: .destructive) { confirmClear = true } label: {
                            Image(systemName: "trash").frame(minWidth: 28, minHeight: 28)
                        }
                        .disabled(model.history.isEmpty)
                        .accessibilityLabel(Text("history.clear", bundle: .main))
                        .accessibilityIdentifier("history.clear")
                        Button(action: close) {
                            Image(systemName: "xmark").frame(minWidth: 28, minHeight: 28)
                        }
                        .accessibilityLabel(Text("history.done", bundle: .main))
                        .accessibilityIdentifier("history.done")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 6)
            HistoryList(onSelect: close)
        }
        .background(GlassShapes.panel.fill(.regularMaterial))
        .clipShape(GlassShapes.panel)
        .overlay(GlassShapes.panel.strokeBorder(Color.primary.opacity(scheme == .dark ? 0.12 : 0.08)))
        .padding(12)
        .clearHistoryConfirmation(isPresented: $confirmClear)
    }
}

/// The rows, newest first. Tapping one puts its result back into the calculator; swiping deletes it.
struct HistoryList: View {
    let onSelect: () -> Void

    @Environment(CalculatorModel.self) private var model

    var body: some View {
        if model.history.isEmpty {
            ContentUnavailableView {
                Label { Text("history.empty.title", bundle: .main) } icon: { Image(systemName: "clock.arrow.circlepath") }
            } description: {
                Text("history.empty.message", bundle: .main)
            }
        } else {
            List {
                ForEach(model.history) { row in
                    Button {
                        model.recall(row)
                        onSelect()
                    } label: {
                        HistoryRowView(row: row)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("history.row")
                }
                .onDelete { offsets in
                    offsets.map { model.history[$0] }.forEach(model.deleteHistoryEntry)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct HistoryRowView: View {
    let row: HistoryRow

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(verbatim: (row.expression ?? "…") + " =")
                .font(Typography.expression(compact: true))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.trailing)
            Text(verbatim: row.result)
                .font(Typography.primary(size: 30))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(row.date, format: .dateTime.hour().minute())
                .font(Typography.indicator())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: SpokenNumber.spoken((row.expression ?? "") + " = " + row.result)))
        .accessibilityHint(Text("history.reuse.hint", bundle: .main))
        .accessibilityAddTraits(.isButton)
    }
}

private extension View {
    func clearHistoryConfirmation(isPresented: Binding<Bool>) -> some View {
        modifier(ClearHistoryConfirmation(isPresented: isPresented))
    }
}

private struct ClearHistoryConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(CalculatorModel.self) private var model

    func body(content: Content) -> some View {
        content.confirmationDialog(Text("history.clear.confirm", bundle: .main), isPresented: $isPresented, titleVisibility: .visible) {
            Button(role: .destructive) { model.clearHistory() } label: { Text("history.clear", bundle: .main) }
        }
    }
}
