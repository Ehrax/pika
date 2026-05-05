import XCTest

extension XCUIApplication {
    static func billbiUITestApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BILLBI_UI_TESTING"] = "1"
        return app
    }
}
