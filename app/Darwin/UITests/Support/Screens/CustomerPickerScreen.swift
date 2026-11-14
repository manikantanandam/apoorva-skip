//
//  CustomerPickerScreen.swift
//  ApoorvaUITests
//
//  Page object for "Customer for this bill".
//

import XCTest

@MainActor
struct CustomerPickerScreen {
    let app: XCUIApplication

    var title: XCUIElement { app.navigationBars["Customer for this bill"] }
    var searchField: XCUIElement { app.textFields["Name or phone"] }
    var phoneField: XCUIElement { app.textFields["98480 55667"] }
    var walkInButton: XCUIElement { app.buttons[AccessibilityID.CustomerPicker.walkIn] }
    var addAndAttachButton: XCUIElement { app.buttons[AccessibilityID.CustomerPicker.addAndAttach] }

    func customer(named name: String) -> XCUIElement { app.staticTexts[name].firstMatch }

    func waitForScreen(timeout: TimeInterval = 10) {
        XCTAssertTrue(title.waitForExistence(timeout: timeout), "Customer picker did not appear")
    }
}
