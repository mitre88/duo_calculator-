import SwiftUI
import UIKit
import CalcEngine

/// What the root presents over the calculator. On the inner display History is a fold-aware panel instead of a sheet.
enum RootSheet: String, Identifiable {
    case settings, history, converter
    var id: String { rawValue }
}

/// Root of the UI. Measures the window, resolves the layout plan (size classes + reserved regions),
/// and hosts the background, the calculator and the panels. Hinge data only feeds effects.
struct CalculatorRootView: View {
    @Environment(CalculatorModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(DeviceContext.self) private var deviceContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var sheet: RootSheet?
    @FocusState private var keyboardFocused: Bool

    /// On the inner display History is a panel beside the calculator (see `LayoutResolver.historyFrame`).
    private func historyIsPanel(_ plan: LayoutPlan) -> Bool {
        plan.historyFrame != nil && (!plan.panelsAvailable || model.mode == .scientific)
    }

    /// Hardware keys drive the calculator while it is on screen: not under a sheet, nor behind the programmer or
    /// converter panels. The History panel leaves the calculator beside it live.
    private var keysReachCalculator: Bool {
        let plan = deviceContext.plan
        let calculatorVisible = !plan.panelsAvailable || model.mode == .scientific
        let modal = sheet != nil && !(sheet == .history && historyIsPanel(plan))
        return calculatorVisible && !modal
    }

    /// Everything but the History panel is a sheet. While History is a panel the binding reads nil, and SwiftUI's
    /// nil write-back when it dismisses a sheet for that reason is ignored, so unfolding hands the sheet to the panel.
    private func presentedSheet(for plan: LayoutPlan) -> Binding<RootSheet?> {
        let panel = historyIsPanel(plan)
        return Binding(
            get: { sheet == .history && panel ? nil : sheet },
            set: { newValue in
                if newValue == nil, sheet == .history, panel { return }
                sheet = newValue
            })
    }

    var body: some View {
        // The outer reader respects the safe area only to read its insets; the inner one spans the whole
        // window, so the background bleeds edge to edge and the plan works in window coordinates.
        GeometryReader { safeProxy in
            calculatorLayer(safeArea: safeProxy.safeAreaInsets)
                .ignoresSafeArea()
        }
        // The converter's keyboard must not shrink the pane: below the panel height the layout would drop the
        // panel together with its focused field, hiding the keyboard again in a loop.
        .ignoresSafeArea(.keyboard)
        .observesHinge()
        .sensoryFeedback(trigger: model.hapticTick) { _, _ in
            settings.hapticsEnabled ? Haptics.feedback(for: model.lastHaptic) : nil
        }
        .sensoryFeedback(trigger: deviceContext.foldTransitionTick) { _, _ in
            settings.hapticsEnabled ? Haptics.feedback(for: .soft) : nil
        }
        .focusable()
        .focused($keyboardFocused)
        .focusEffectDisabled()
        .onKeyPress { press in
            if press.key == .escape, sheet == .history {
                sheet = nil
                return .handled
            }
            return keysReachCalculator ? model.handleKeyPress(press) : .ignored
        }
        .onAppear {
            keyboardFocused = true
            #if DEBUG
            ScreenshotHooks.apply(to: model) { sheet = $0 }
            #endif
        }
        .onChange(of: sheet) { _, presented in
            if presented == nil { keyboardFocused = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive { model.saveNow() }
        }
        .onChange(of: settings.usesGrouping, initial: true) { _, grouping in
            model.usesGrouping = grouping
        }
        .onChange(of: settings.keepScreenAwake, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .statusBarHidden(false)
    }

    private func sheetContent(_ item: RootSheet, plan: LayoutPlan) -> some View {
        Group {
            switch item {
            case .settings:
                SettingsView()
            case .history:
                HistorySheet()
            case .converter:
                UnitConverterPanel(plan: plan, presentation: .sheet)
                    .presentationDetents([.large])
            }
        }
        .environment(settings)
        .environment(model)
    }

    private func calculatorLayer(safeArea: EdgeInsets) -> some View {
        GeometryReader { proxy in
            let input = LayoutInput(
                size: proxy.size,
                safeArea: safeArea,
                sizeClass: SizeClassPair(horizontal: horizontalSizeClass == .regular ? .regular : .compact,
                                         vertical: verticalSizeClass == .compact ? .compact : .regular),
                regions: proxy.duoReservedRegions(),
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                prefersScientificInCompactLandscape: settings.scientificInFoldedLandscape,
                prefersScientificInCompactPortrait: settings.scientificInCompactPortrait)
            let plan = LayoutResolver.resolve(input)

            ZStack(alignment: .topLeading) {
                AuroraBackground(scheme: colorScheme,
                                 trueBlack: settings.oledTrueBlack,
                                 enabled: settings.auroraEnabled,
                                 reduceMotion: reduceMotion,
                                 accent: settings.accent.color,
                                 interactionTick: model.hapticTick)
                FoldAwareContainer(plan: plan, sheet: $sheet)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            // Only a *mode* change animates (the fold morph); raw resize frames follow instantly, no jitter.
            .animation(Motion.layout(reduceMotion: reduceMotion), value: plan.mode)
            .onChange(of: plan.displayProfile, initial: true) { _, profile in
                model.displayProfile = profile
            }
            .onChange(of: plan, initial: true) { _, newPlan in
                deviceContext.plan = newPlan
            }
            // Attached where the plan is fresh, so a fold hands History between sheet and panel in the same pass.
            .sheet(item: presentedSheet(for: plan)) { item in
                sheetContent(item, plan: plan)
            }
        }
    }
}
