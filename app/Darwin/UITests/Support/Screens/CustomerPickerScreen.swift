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
    var nameField: XCUIElement { app.textFields["Kiran"] }
    var newCustomerHeader: XCUIElement { app.staticTexts["New customer"] }
    var recentHeader: XCUIElement { app.staticTexts["Recent"] }
    var walkInButton: XCUIElement { app.buttons[AccessibilityID.CustomerPicker.walkIn] }
    var addAndAttachButton: XCUIElement { app.buttons[AccessibilityID.CustomerPicker.addAndAttach] }

    /// List row only. Static-text lookups also match the Home screen kept in the tree under the full-screen cover.
    func customer(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", \(name), ")).firstMatch
    }

    /// "Recent" chip, labelled with just the name.
    func recentChip(named name: String) -> XCUIElement { app.buttons[name] }

    func waitForScreen(timeout: TimeInterval = 10) {
        XCTAssertTrue(title.waitForExistence(timeout: timeout), "Customer picker did not appear")
    }
}
