//
//  POSScreen.swift
//  ApoorvaUITests
//
//  Page object for the New bill (POS) screen.
//

import XCTest

@MainActor
struct POSScreen {
    let app: XCUIApplication

    var customerRow: XCUIElement { app.buttons[AccessibilityID.Pos.customerRow] }
    var walkInLabel: XCUIElement { app.staticTexts["Walk-in customer"] }
    var emptyCartLabel: XCUIElement { app.staticTexts["Your cart is empty"] }
    var checkoutButton: XCUIElement { app.buttons["Proceed to checkout"] }

    func item(named name: String) -> XCUIElement { app.buttons[name] }

    func waitForScreen(timeout: TimeInterval = 10) {
        XCTAssertTrue(customerRow.waitForExistence(timeout: timeout), "POS screen did not appear")
    }

    func openCustomerPicker() {
        customerRow.tap()
    }
}
