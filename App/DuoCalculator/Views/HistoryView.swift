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
                    // Not the cancellation slot: Esc must close the sheet, never start clearing it.
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) { confirmClear = true } label: { Text("history.clear", bundle: .main) }
                            .disabled(model.history.isEmpty)
                            .accessibilityIdentifier("history.clear")
                            .clearHistoryConfirmation(isPresented: $confirmClear)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: { Text("history.done", bundle: .main) }
                            .accessibilityIdentifier("history.done")
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

/// History as a panel inside the inner display, at the frame `LayoutResolver.historyFrame` keeps clear of the fold.
struct HistoryPanel: View {
    /// The plan's clearance below the status bar and cameras over the panel's top edge.
    let topInset: CGFloat
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
                            Image(systemName: "trash").frame(minWidth: 32, minHeight: 32)
                        }
                        .disabled(model.history.isEmpty)
                        .accessibilityLabel(Text("history.clear", bundle: .main))
                        .accessibilityIdentifier("history.clear")
                        .clearHistoryConfirmation(isPresented: $confirmClear)
                        Button(action: close) {
                            Image(systemName: "xmark").frame(minWidth: 32, minHeight: 32)
                        }
                        .accessibilityLabel(Text("history.done", bundle: .main))
                        .accessibilityIdentifier("history.done")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, max(16, topInset))
            .padding(.bottom, 6)
            HistoryList(onSelect: close)
        }
        .background(GlassShapes.panel.fill(.regularMaterial))
        .clipShape(GlassShapes.panel)
        .overlay(GlassShapes.panel.strokeBorder(Color.primary.opacity(scheme == .dark ? 0.12 : 0.08)))
        .padding(12)
        // VoiceOver stays inside the panel; the escape gesture closes it.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
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

    /// Today shows the time; older entries add the day.
    private var dateText: Text {
        Calendar.current.isDateInToday(row.date)
            ? Text(row.date, format: .dateTime.hour().minute())
            : Text(row.date, format: .dateTime.day().month(.abbreviated).hour().minute())
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(verbatim: (row.expression ?? "…") + " =")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.trailing)
            Text(verbatim: row.result)
                .font(.system(.title, design: .rounded, weight: .light))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            dateText
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenLabel))
        .accessibilityValue(dateText)
        .accessibilityHint(Text("history.reuse.hint", bundle: .main))
        .accessibilityAddTraits(.isButton)
    }

    /// Expression and result are spoken separately, so each keeps its own number reading.
    private var spokenLabel: String {
        let result = SpokenNumber.spoken(row.result)
        guard let expression = row.expression else { return result }
        return SpokenNumber.spoken(expression) + ", = " + result
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
                .accessibilityIdentifier("history.clear.confirm")
        }
    }
}
