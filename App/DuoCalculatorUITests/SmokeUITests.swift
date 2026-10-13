import XCTest

/// Real taps through XCUITest, on any iPhone simulator (the iPhone Duo included). Each test adapts to the layout it
/// finds: wide layouts (the open Duo) switch programmer / converter in place, compact ones (phones, the folded Duo)
/// offer Basic / Scientific and open the converter as a sheet.
///
/// The posture test also needs a host that folds the Duo from Xcode's Device Hub while it waits
/// (`TEST_RUNNER_DUO_POSTURE_HARNESS=1 xcodebuild test …`).
final class SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Helpers

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["key.equals"].waitForExistence(timeout: 10), "the calculator did not appear")
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

    @MainActor
    private func display(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Result' OR label == 'Error'")).firstMatch
    }

    @MainActor
    private func value(_ app: XCUIApplication) -> String {
        String(describing: display(app).value ?? "")
    }

    @MainActor
    private func openHistory(_ app: XCUIApplication) {
        let button = app.buttons["modebar.history"]
        if button.waitForExistence(timeout: 3) {
            button.tap()
            return
        }
        // Narrow displays fold History into the "more" menu.
        let more = app.buttons["modebar.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 3), "no way to open History")
        more.tap()
        app.buttons["history"].firstMatch.tap()
    }

    /// Opens the mode menu and reports whether this layout switches programmer / converter in place.
    @MainActor
    private func openModeMenu(_ app: XCUIApplication) -> Bool {
        let mode = app.buttons["modebar.mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5), "no mode menu")
        mode.tap()
        return app.buttons["Programmer"].waitForExistence(timeout: 2)
    }

    // MARK: Tests

    @MainActor
    func testArithmeticAndErrors() throws {
        let app = launch()
        press(app, "allClear", "allClear", "digit.2", "add", "digit.3", "equals")
        XCTAssertTrue(value(app).contains("5"), value(app))
        press(app, "equals", "equals")
        XCTAssertTrue(value(app).contains("11"), value(app))
        press(app, "allClear", "allClear", "digit.1", "divide", "digit.0", "equals")
        XCTAssertEqual(display(app).label, "Error")
        press(app, "allClear", "digit.7", "multiply", "digit.6", "equals")
        XCTAssertTrue(value(app).contains("42"), value(app))
    }

    @MainActor
    func testHistoryRecallsAResult() throws {
        let app = launch()
        press(app, "allClear", "allClear", "digit.1", "digit.2", "multiply", "digit.3", "equals")
        XCTAssertTrue(value(app).contains("36"), value(app))
        press(app, "allClear", "digit.2", "add", "digit.2", "equals")
        XCTAssertTrue(value(app).contains("4"), value(app))

        openHistory(app)
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "History shows no rows")
        XCTAssertGreaterThanOrEqual(rows.count, 2)
        // Newest first: "2 + 2 = 4", then "12 × 3 = 36".
        rows.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["key.equals"].waitForExistence(timeout: 5))
        XCTAssertTrue(value(app).contains("36"), value(app))
        press(app, "add", "digit.4", "equals")
        XCTAssertTrue(value(app).contains("40"), value(app))
    }

    @MainActor
    func testHistoryClearsEverything() throws {
        let app = launch()
        press(app, "allClear", "allClear", "digit.5", "multiply", "digit.5", "equals")
        openHistory(app)
        let clear = app.buttons["history.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        let confirm = app.sheets.buttons["Clear History"].exists
            ? app.sheets.buttons["Clear History"]
            : app.buttons.matching(NSPredicate(format: "label == 'Clear History'")).element(boundBy: 1)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "no confirmation")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["No Calculations Yet"].waitForExistence(timeout: 5), "History is not empty")
        app.buttons["history.done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["key.equals"].waitForExistence(timeout: 5))
    }

    /// Regular iPhones keep what LiquidCalculator sold: scientific keys and the unit converter.
    @MainActor
    func testCompactLayoutsReachScientificAndConverter() throws {
        let app = launch()
        if openModeMenu(app) {
            app.buttons["Scientific"].firstMatch.tap()
            throw XCTSkip("wide layout: covered by testProgrammerAndConverterOnTheInnerDisplay")
        }
        let scientific = app.buttons["Scientific"]
        XCTAssertTrue(scientific.waitForExistence(timeout: 5), "no Basic / Scientific choice here")
        scientific.tap()
        XCTAssertTrue(app.buttons["key.sine"].waitForExistence(timeout: 5), "scientific keys did not appear")
        press(app, "allClear", "allClear", "digit.3", "digit.0", "sine", "equals")
        XCTAssertTrue(value(app).contains("0.5"), value(app))

        _ = openModeMenu(app)
        app.buttons["Units"].firstMatch.tap()
        let field = app.textFields["value to convert"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the converter sheet did not open")
        let result = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'conversion result'")).firstMatch
        XCTAssertTrue(result.exists)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["key.equals"].waitForExistence(timeout: 5))

        _ = openModeMenu(app)
        app.buttons["Basic"].firstMatch.tap()
        XCTAssertFalse(app.buttons["key.sine"].waitForExistence(timeout: 2), "Basic kept the scientific keys")
    }

    @MainActor
    func testProgrammerAndConverterOnTheInnerDisplay() throws {
        let app = launch()
        guard openModeMenu(app) else {
            app.buttons["Units"].firstMatch.tap()
            app.buttons["Done"].firstMatch.tap()
            throw XCTSkip("compact layout: covered by testCompactLayoutsReachScientificAndConverter")
        }
        app.buttons["Programmer"].tap()
        XCTAssertTrue(app.buttons["HEX"].waitForExistence(timeout: 5))
        app.buttons["HEX"].tap()
        for label in ["AC", "F", "AND", "3", "="] { app.buttons[label].firstMatch.tap() }
        XCTAssertTrue(value(app).contains("3"), value(app))

        app.buttons["Programmer"].firstMatch.tap()      // the panel's own mode menu
        let units = app.buttons["Units"]
        XCTAssertTrue(units.waitForExistence(timeout: 5))
        units.tap()
        let field = app.textFields["value to convert"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "2")
        XCTAssertTrue(field.exists, "the converter must stay mounted while its field is focused")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        app.buttons["Units"].firstMatch.tap()
        let scientific = app.buttons["Scientific"]
        XCTAssertTrue(scientific.waitForExistence(timeout: 5))
        scientific.tap()
        XCTAssertTrue(app.buttons["key.equals"].waitForExistence(timeout: 5))
    }

    /// Turning a phone gives the scientific keypad (beside the display on 6.1"/6.3" screens).
    @MainActor
    func testLandscapeIsScientific() throws {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["key.sine"].waitForExistence(timeout: 5), "no scientific keys in landscape")
        press(app, "allClear", "allClear", "digit.9", "squareRoot", "equals")
        XCTAssertTrue(value(app).contains("3"), value(app))
    }

    /// 7! = 5040, then 5040! has 16 474 digits: the display's doubleValue used to trap on it (build 5).
    @MainActor
    func testHugeFactorialDoesNotCrash() throws {
        let app = launch()
        let switchedToScientific = !app.buttons["key.factorial"].exists
        if switchedToScientific {
            _ = openModeMenu(app)
            app.buttons["Scientific"].firstMatch.tap()
        }
        press(app, "allClear", "allClear", "digit.7", "factorial", "factorial", "equals")
        XCTAssertTrue(display(app).waitForExistence(timeout: 30))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(value(app).contains("16473") || value(app).contains("16,473"), value(app))
        press(app, "allClear", "digit.2", "add", "digit.2", "equals")
        XCTAssertTrue(value(app).contains("4"), value(app))
        if switchedToScientific {
            _ = openModeMenu(app)
            app.buttons["Basic"].firstMatch.tap()
        }
    }

    /// A fold in the middle of a calculation keeps the expression (the host flips the Duo from Device Hub).
    @MainActor
    func testPostureChangeMidCalculation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DUO_POSTURE_HARNESS"] == "1", "needs the Device Hub harness")
        let app = launch()
        press(app, "allClear", "allClear", "digit.1", "digit.2", "digit.3", "add", "digit.4", "digit.5")
        sleep(25)                                      // the host flips the Duo's posture meanwhile
        press(app, "equals")
        XCTAssertTrue(value(app).contains("168"), value(app))
    }
}
