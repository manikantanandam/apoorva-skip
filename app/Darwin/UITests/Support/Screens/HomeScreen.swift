//
//  HomeScreen.swift
//  ApoorvaUITests
//
//  Page object for Splash -> Demo shop -> Home tabs. The demo shop is the only signed-in-like
//  state reachable offline, so feature tests enter through it.
//

import XCTest

@MainActor
struct HomeScreen {
    let app: XCUIApplication

    var demoButton: XCUIElement { app.buttons[AccessibilityID.Splash.demo] }
    var trySampleButton: XCUIElement { app.buttons[AccessibilityID.DemoShop.trySample] }
    var newBillButton: XCUIElement { app.buttons["New bill"] }

    /// Splash -> demo shop -> home tabs with the sample shop seeded.
    func enterDemoShop(timeout: TimeInterval = 10) {
        XCTAssertTrue(demoButton.waitForExistence(timeout: timeout), "Splash did not appear")
        demoButton.tap()
        XCTAssertTrue(trySampleButton.waitForExistence(timeout: timeout), "Demo shop did not appear")
        trySampleButton.tap()
        XCTAssertTrue(newBillButton.waitForExistence(timeout: timeout * 2), "Home did not appear")
    }

    func openNewBill() {
        newBillButton.tap()
    }
}
