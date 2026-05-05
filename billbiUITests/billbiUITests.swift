//
//  billbiUITests.swift
//  billbiUITests
//
//  Created by Alexander Rasputin on 26.04.26.
//

import XCTest

final class billbiUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication.billbiUITestApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication.billbiUITestApplication().launch()
        }
    }
}
