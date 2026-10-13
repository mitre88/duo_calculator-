import SwiftUI
import CalcEngine

/// Positions the display and the keypad(s) at the frames of the `LayoutPlan`, and keeps every key
/// inside **one** `GlassEffectContainer` so they can morph between arrangements.
struct FoldAwareContainer: View {
    let plan: LayoutPlan
    @Binding var sheet: RootSheet?

    @Environment(CalculatorModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceContext.self) private var deviceContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var keypadNamespace

    /// Programmer and converter need the flat inner display; in compact widths and around an active fold
    /// (Laptop / Book poses) the scientific calculator takes over. The chosen mode is kept, so the panel
    /// returns as soon as the pose allows it.
    private var effectiveMode: CalculatorModel.Mode {
        plan.panelsAvailable ? model.mode : .scientific
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch effectiveMode {
            case .scientific:
                calculator
                    .transition(.opacity)
            case .programmer:
                ProgrammerPanel(plan: plan)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            case .converter:
                UnitConverterPanel(plan: plan)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            // On the inner display History opens beside the fold (see `LayoutResolver.historyFrame`).
            if sheet == .history, effectiveMode == .scientific, let frame = plan.historyFrame {
                HistoryPanel { sheet = nil }
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(Motion.layout(reduceMotion: reduceMotion), value: effectiveMode)
        .animation(Motion.panel, value: sheet == .history)
    }

    private var calculator: some View {
        ZStack(alignment: .topLeading) {
            DisplayView(snapshot: model.snapshot, plan: plan, hinge: deviceContext.hinge, sheet: $sheet)
                .frame(width: plan.displayFrame.width, height: plan.displayFrame.height)
                .offset(x: plan.displayFrame.minX, y: plan.displayFrame.minY)

            GlassEffectContainer(spacing: 14) {
                ZStack(alignment: .topLeading) {
                    if let frame = plan.secondaryKeypadFrame, let spec = plan.secondaryKeypadSpec {
                        KeypadView(spec: spec, plan: plan, keySize: plan.secondaryKeySize ?? plan.keySize, namespace: keypadNamespace)
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: frame.minY)
                    }
                    KeypadView(spec: plan.keypadSpec, plan: plan, keySize: plan.keySize, namespace: keypadNamespace)
                        .frame(width: plan.keypadFrame.width, height: plan.keypadFrame.height)
                        .offset(x: plan.keypadFrame.minX, y: plan.keypadFrame.minY)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
