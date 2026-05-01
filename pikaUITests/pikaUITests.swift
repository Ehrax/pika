//
//  pikaUITests.swift
//  pikaUITests
//
//  Created by Alexander Rasputin on 26.04.26.
//

import XCTest

final class pikaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication.pikaUITestApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication.pikaUITestApplication().launch()
        }
    }
}
