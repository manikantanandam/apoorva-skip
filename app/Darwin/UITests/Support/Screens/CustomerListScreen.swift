//
//  CustomerListScreen.swift
//  ApoorvaUITests
//
//  Page object for the Customers tab (list, search, filter chips, add).
//

import XCTest

@MainActor
struct CustomerListScreen {
    let app: XCUIApplication

    var title: XCUIElement { app.staticTexts["Customers"] }
    var searchField: XCUIElement { app.textFields["Name or phone"] }
    var addButton: XCUIElement { app.buttons["Add customer"] }
    var moreMenu: XCUIElement { app.buttons[AccessibilityID.Customers.moreMenu] }
    var noMatch: XCUIElement { app.staticTexts["No match"] }

    /// "5 customers · ₹1,120 due" button above the search field.
    func summary(_ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func chip(_ name: String) -> XCUIElement { app.buttons[name] }

    /// List row only (label is "Name, phone · visits…").
    func row(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name), ")).firstMatch
    }

    func waitForScreen(timeout: TimeInterval = 10) {
        XCTAssertTrue(searchField.waitForExistence(timeout: timeout), "Customers list did not appear")
    }

    func search(_ text: String) {
        searchField.tap()
        searchField.typeText(text)
    }

    func select(filter name: String) { chip(name).tap() }
}
