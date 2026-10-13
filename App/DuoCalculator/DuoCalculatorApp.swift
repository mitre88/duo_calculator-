import SwiftUI
import CalcEngine

@main
struct DuoCalculatorApp: App {
    @State private var settings: AppSettings
    @State private var model: CalculatorModel
    @State private var deviceContext = DeviceContext()

    init() {
        #if DEBUG
        ScreenshotHooks.resetIfRequested()
        #endif
        _settings = State(initialValue: AppSettings())
        _model = State(initialValue: CalculatorModel())
    }

    var body: some Scene {
        WindowGroup {
            CalculatorRootView()
                .environment(settings)
                .environment(model)
                .environment(deviceContext)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(settings.accent.color)
                .task { await model.restoreIfNeeded() }
        }
    }
}
