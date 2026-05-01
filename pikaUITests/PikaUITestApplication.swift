import XCTest

extension XCUIApplication {
    static func pikaUITestApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["PIKA_UI_TESTING"] = "1"
        return app
    }
}
