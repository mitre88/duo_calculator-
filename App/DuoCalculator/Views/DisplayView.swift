import SwiftUI
import UIKit
import CalcEngine

/// Expression line (with cursor), live preview, main result and the mode bar.
struct DisplayView: View {
    let snapshot: DisplaySnapshot
    let plan: LayoutPlan
    let hinge: HingeState
    @Binding var showSettings: Bool

    @Environment(CalculatorModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private var compact: Bool { plan.isCompactWidth }

    /// Keep the text below the inner camera (an active occlusion that overlaps the display).
    private var topInset: CGFloat {
        let overlapping = plan.avoidRects.filter { $0.intersects(plan.displayFrame) }
        guard let lowest = overlapping.map({ $0.maxY - plan.displayFrame.minY }).max() else { return 8 }
        return max(8, lowest + 12)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: compact ? 4 : 8) {
            ModeBar(snapshot: snapshot, plan: plan, showSettings: $showSettings)
                .padding(.top, topInset)
            Spacer(minLength: 0)
            ExpressionLineView(segments: snapshot.expression, showsCursor: !snapshot.showsResult && !snapshot.isError, compact: compact) { index in
                model.send(.cursorTo(index))
            }
            if let preview = snapshot.preview {
                Text(verbatim: "= " + preview)
                    .font(Typography.preview(compact: compact))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .transition(.opacity)
                    .accessibilityLabel(Text("display.preview", bundle: .main))
                    .accessibilityValue(Text(verbatim: SpokenNumber.spoken(preview)))
            }
            primaryLine
            IndicatorRow(snapshot: snapshot)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, compact ? 18 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .rotation3DEffect(.degrees(plan.mode == .tabletop && !reduceMotion ? hinge.displayTiltDegrees : 0),
                          axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
        .animation(Motion.digits(reduceMotion: reduceMotion), value: snapshot.primary)
        .animation(Motion.layout(reduceMotion: reduceMotion), value: snapshot.preview)
        .contextMenu {
            Button {
                UIPasteboard.general.string = snapshot.primary
            } label: {
                Label { Text("display.copy", bundle: .main) } icon: { Image(systemName: "doc.on.doc") }
            }
            Button {
                if let text = UIPasteboard.general.string { model.send(.insertText(text)) }
            } label: {
                Label { Text("display.paste", bundle: .main) } icon: { Image(systemName: "doc.on.clipboard") }
            }
        }
    }

    private var primaryLine: some View {
        let size = Typography.primarySize(displayHeight: plan.displayFrame.height, compact: compact)
        return Text(verbatim: snapshot.primary)
            .font(Typography.primary(size: size))
            .monospacedDigit()
            .foregroundStyle(snapshot.isError ? Palette.error : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentTransition(.numericText(value: snapshot.primaryValue?.doubleValue ?? 0))
            .resultFeedback(trigger: model.resultTick, isError: snapshot.isError, reduceMotion: reduceMotion)
            .privacySensitive()
            // Swipe on the number deletes the last token (iOS convention); kept off the scrolling expression line.
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            model.send(.backspace, haptic: .light)
                        }
                    }
            )
            .accessibilityLabel(Text(LocalizedStringKey(snapshot.isError ? "display.error" : "display.result"), bundle: .main))
            .accessibilityValue(Text(verbatim: snapshot.isError ? SpokenNumber.errorDescription(snapshot.errorReason) : SpokenNumber.spoken(snapshot.primary)))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The expression tokens, horizontally scrollable, with a blinking cursor you can place by tapping.
struct ExpressionLineView: View {
    let segments: [DisplaySegment]
    let showsCursor: Bool
    let compact: Bool
    let placeCursor: (Int) -> Void

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    ForEach(segments) { segment in
                        segmentView(segment)
                    }
                }
                .padding(.vertical, 4)
                .frame(minWidth: 0, alignment: .trailing)
            }
            .defaultScrollAnchor(.trailing)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: segments) { _, _ in
                if showsCursor, let cursor = segments.first(where: { $0.kind == .cursor }) {
                    withAnimation(.easeOut(duration: 0.15)) { reader.scrollTo(cursor.id, anchor: .trailing) }
                }
            }
        }
        .font(Typography.expression(compact: compact))
        .foregroundStyle(.secondary)
        .frame(height: compact ? 28 : 34)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("display.expression", bundle: .main))
        .accessibilityValue(Text(verbatim: SpokenNumber.spoken(segments.map(\.text).joined())))
    }

    @ViewBuilder
    private func segmentView(_ segment: DisplaySegment) -> some View {
        switch segment.kind {
        case .cursor:
            CursorBar(visible: showsCursor)
                .id(segment.id)
        case .equals:
            Text(verbatim: segment.text).foregroundStyle(.tertiary).id(segment.id)
        default:
            Text(verbatim: segment.text)
                .foregroundStyle(segment.kind == .binaryOperator ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                .id(segment.id)
                .overlay {
                    if let index = segment.tokenIndex {
                        HStack(spacing: 0) {
                            Color.clear.contentShape(Rectangle()).onTapGesture { placeCursor(index) }
                            Color.clear.contentShape(Rectangle()).onTapGesture { placeCursor(index + 1) }
                        }
                    }
                }
        }
    }
}

struct CursorBar: View {
    let visible: Bool
    @State private var on = true

    var body: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 2, height: 22)
            .opacity(visible && on ? 1 : 0)
            .padding(.horizontal, 1)
            .task(id: visible) {
                on = true
                guard visible else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(560))
                    on.toggle()
                }
            }
            .accessibilityHidden(true)
    }
}

/// Small pills: Deg/Rad, 2nd, memory.
struct IndicatorRow: View {
    let snapshot: DisplaySnapshot

    var body: some View {
        HStack(spacing: 8) {
            pill(snapshot.angleMode.shortLabel, active: snapshot.angleMode == .radians)
            if snapshot.isSecondActive { pill("2nd", active: true) }
            if snapshot.memoryActive { pill("M", active: true) }
        }
        .font(Typography.indicator())
        .accessibilityElement(children: .combine)
    }

    private func pill(_ text: String, active: Bool) -> some View {
        Text(verbatim: text)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(active ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.12)))
            .foregroundStyle(active ? Color.accentColor : Color.secondary)
    }
}
