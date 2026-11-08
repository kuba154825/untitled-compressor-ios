import XCTest

final class ControlsTests: XCTestCase {
    @MainActor
    func testSizeControlsBeforeAddingFiles() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.buttons["languageEN"].tap()
        app.segmentedControls["compressionMode"].buttons["Target MB"].tap()
        XCTAssertTrue(app.textFields["targetMB"].waitForExistence(timeout: 5))
        let field = app.textFields["targetMB"]; field.tap()
        field.press(forDuration: 1.2)
        // Select all through keyboard rather than assuming a locale-specific decimal separator.
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "5")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["preset75"].tap()
        XCTAssertTrue(app.sliders["compressionSlider"].exists)
        XCTAssertTrue(app.staticTexts["Output: 25% of original size"].exists)
        app.segmentedControls["compressionMode"].buttons["Target MB"].tap()
        XCTAssertTrue(app.textFields["targetMB"].exists)
        XCTAssertFalse(app.buttons["compress"].isEnabled)
        app.buttons["languagePL"].tap()
        XCTAssertTrue(app.staticTexts["Maksymalny rozmiar wyniku · MB"].exists)
        XCTAssertFalse(app.staticTexts["VIDEO FIRST · AUDIO SECOND"].exists)
    }
}
