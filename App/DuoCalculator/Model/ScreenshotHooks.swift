#if DEBUG
import SwiftUI

/// Debug-only launch hooks for UI tests and the App Store captures (`SmokeUITests`, `ScreenshotUITests`). They are
/// plain defaults, so the tests set them as launch arguments (`-duo.screenshot.mode programmer`). Release builds
/// compile none of this.
///
///   duo.uitest.reset       YES: start with no saved state, settings or History
///   duo.screenshot.mode    scientific | programmer | converter   (the inner display's panels)
///   duo.screenshot.sheet   history | converter | settings
enum ScreenshotHooks {
    /// Runs before `AppSettings` and `CalculatorModel` read the defaults.
    static func resetIfRequested() {
        guard UserDefaults.standard.bool(forKey: "duo.uitest.reset"), let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }

    static func apply(to model: CalculatorModel, present: (RootSheet) -> Void) {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "duo.screenshot.mode"), let mode = CalculatorModel.Mode(rawValue: raw) {
            model.mode = mode
        }
        if let raw = defaults.string(forKey: "duo.screenshot.sheet"), let sheet = RootSheet(rawValue: raw) {
            present(sheet)
        }
    }
}
#endif
