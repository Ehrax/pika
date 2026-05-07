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
    func testFirstRunLaunchPresentsOnboardingBeforeTheDashboard() throws {
        let app = XCUIApplication.billbiUITestApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["Billbi Onboarding"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["DashboardView"].exists)
    }

    @MainActor
    func testSkippingOnboardingEntersTheDashboard() throws {
        let app = XCUIApplication.billbiUITestApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["Billbi Onboarding"].waitForExistence(timeout: 5))
        app.buttons["Skip setup"].click()

        XCTAssertTrue(app.otherElements["DashboardView"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["Billbi Onboarding"].exists)
    }

    @MainActor
    func testOnboardingCanCompleteWithBlankOptionalDrafts() throws {
        let app = XCUIApplication.billbiUITestApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["Billbi Onboarding"].waitForExistence(timeout: 5))

        for _ in 0..<5 {
            let continueButton = app.buttons["Continue"]
            XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
            continueButton.click()
        }

        XCTAssertTrue(app.otherElements["DashboardView"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["Billbi Onboarding"].exists)
    }

    @MainActor
    func testDebugResetReturnsCompletedWorkspaceToOnboarding() throws {
        let app = XCUIApplication.billbiUITestApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["Billbi Onboarding"].waitForExistence(timeout: 5))
        app.buttons["Skip setup"].click()
        XCTAssertTrue(app.otherElements["DashboardView"].waitForExistence(timeout: 5))

        app.typeKey("o", modifierFlags: [.command, .shift, .option])

        XCTAssertTrue(app.otherElements["Billbi Onboarding"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["DashboardView"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication.billbiUITestApplication().launch()
        }
    }
}
