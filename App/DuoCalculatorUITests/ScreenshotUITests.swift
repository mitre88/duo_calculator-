import XCTest

/// App Store raws through real taps: each test drives the app to one state and attaches a full-screen capture named
/// for `Tools/screenshots/compose.py`. Run the Duo tests on the iPhone Duo (inner display open and flat; the cover
/// test folded; the book test half open, set from Device Hub) and the phone tests on a 6.9" iPhone, once per language:
///
///     TEST_RUNNER_SCREENSHOT_LANG=es xcodebuild test … -only-testing:DuoCalculatorUITests/ScreenshotUITests/testDuoInnerOpen
///     xcrun xcresulttool export attachments --path R.xcresult --output-path raws/
///
/// They skip unless SCREENSHOT_LANG is set, so the regular test run stays fast.
final class ScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(lang == nil, "screenshots run only with TEST_RUNNER_SCREENSHOT_LANG=es|en")
    }

    private var lang: String? { ProcessInfo.processInfo.environment["SCREENSHOT_LANG"] }

    // MARK: Helpers

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += lang == "es"
            ? ["-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX"]
            : ["-AppleLanguages", "(en-US)", "-AppleLocale", "en_US"]
        app.launchArguments += ["-duo.uitest.reset", "YES", "-duo.settings.appearance", "dark"] + extra
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        return app
    }

    @MainActor
    private func press(_ app: XCUIApplication, _ ids: String...) {
        for id in ids {
            let key = app.buttons["key." + id]
            XCTAssertTrue(key.waitForExistence(timeout: 5), "missing key \(id)")
            key.tap()
        }
    }

    /// Lets the result animation and the glass settle, then attaches the whole screen at its native size.
    @MainActor
    private func capture(_ name: String) {
        sleep(2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(name)_\(lang ?? "en")"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func fillHistory(_ app: XCUIApplication) {
        press(app, "allClear", "allClear", "digit.1", "digit.2", "digit.5", "digit.0", "multiply", "digit.1", "digit.6", "percent", "equals")
        press(app, "allClear", "digit.7", "digit.2", "divide", "digit.8", "equals")
        press(app, "allClear", "digit.3", "digit.5", "multiply", "digit.1", "digit.2", "add", "digit.4", "digit.8", "equals")
        press(app, "allClear", "digit.9", "digit.8", "digit.0", "subtract", "digit.2", "digit.4", "digit.5", "equals")
    }

    // MARK: iPhone Duo

    /// Inner display, open and flat: the golden ratio on the full scientific keypad.
    @MainActor
    func testDuoInnerOpen() throws {
        let app = launch()
        press(app, "allClear", "allClear", "openParen", "digit.1", "add", "digit.5", "squareRoot", "closeParen", "divide", "digit.2", "equals")
        capture("duo_inner_open")
    }

    /// Cover display, folded: a percentage on the big basic keys.
    @MainActor
    func testDuoCover() throws {
        let app = launch()
        press(app, "allClear", "allClear", "digit.1", "digit.2", "digit.5", "digit.0", "multiply", "digit.1", "digit.6", "percent", "equals")
        capture("duo_cover_basic")
    }

    /// Half open in Book posture (set from Device Hub): an expression mid-typing, keys on both sides of the fold.
    @MainActor
    func testDuoBook() throws {
        let app = launch()
        press(app, "allClear", "allClear", "digit.2", "power", "digit.1", "digit.0", "subtract", "digit.2", "digit.4")
        capture("duo_book")
    }

    @MainActor
    func testDuoHistory() throws {
        let app = launch()
        fillHistory(app)
        app.buttons["modebar.history"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "history.row").firstMatch.waitForExistence(timeout: 5))
        capture("duo_history")
    }

    @MainActor
    func testDuoProgrammer() throws {
        let app = launch(["-duo.screenshot.mode", "programmer"])
        XCTAssertTrue(app.buttons["HEX"].waitForExistence(timeout: 5))
        app.buttons["HEX"].tap()
        for label in ["AC", "F", "F", "AND", "2", "A", "="] { app.buttons[label].firstMatch.tap() }   // 0xFF AND 0x2A = 42
        capture("duo_prog")
    }

    @MainActor
    func testDuoConverter() throws {
        let app = launch(["-duo.screenshot.mode", "converter"])
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        capture("duo_conv")
    }

    // MARK: 6.9" iPhone

    @MainActor
    func testPhonePortraitScientific() throws {
        let app = launch(["-duo.settings.sciPortrait", "YES"])
        press(app, "allClear", "allClear", "digit.3", "digit.0", "sine", "add", "digit.4", "squareRoot", "equals")
        capture("ip_portrait_sci")
    }

    @MainActor
    func testPhoneHistory() throws {
        let app = launch()
        fillHistory(app)
        app.buttons["modebar.history"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "history.row").firstMatch.waitForExistence(timeout: 5))
        capture("ip_history")
    }

    @MainActor
    func testPhoneLandscape() throws {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        press(app, "allClear", "allClear", "digit.2", "power", "digit.1", "digit.0", "subtract", "digit.2", "digit.4", "equals")
        capture("ip_land")
    }
}
