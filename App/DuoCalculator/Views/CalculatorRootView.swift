import SwiftUI
import UIKit
import CalcEngine

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

    @State private var showSettings = false
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let input = LayoutInput(
                size: proxy.size,
                safeArea: proxy.safeAreaInsets,
                sizeClass: SizeClassPair(horizontal: horizontalSizeClass == .regular ? .regular : .compact,
                                         vertical: verticalSizeClass == .compact ? .compact : .regular),
                regions: proxy.duoReservedRegions(),
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                prefersScientificInCompactLandscape: settings.scientificInFoldedLandscape)
            let plan = LayoutResolver.resolve(input)

            ZStack(alignment: .topLeading) {
                AuroraBackground(scheme: colorScheme,
                                 trueBlack: settings.oledTrueBlack,
                                 enabled: settings.auroraEnabled,
                                 reduceMotion: reduceMotion,
                                 accent: settings.accent.color,
                                 interactionTick: model.hapticTick)
                FoldAwareContainer(plan: plan, showSettings: $showSettings)
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
        }
        .ignoresSafeArea()
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
        .onKeyPress { press in model.handleKeyPress(press) }
        .onAppear { keyboardFocused = true }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive { model.saveNow() }
        }
        .onChange(of: settings.usesGrouping, initial: true) { _, grouping in
            model.usesGrouping = grouping
        }
        .onChange(of: settings.keepScreenAwake, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(settings)
                .environment(model)
        }
        .statusBarHidden(false)
    }
}
