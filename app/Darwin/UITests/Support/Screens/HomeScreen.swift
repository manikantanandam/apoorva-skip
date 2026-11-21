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
    /// `sampleShop` picks a vertical by its sample shop name (e.g. "Sri Lakshmi Stores" = kirana); nil keeps the default (fancy).
    func enterDemoShop(sampleShop: String? = nil, timeout: TimeInterval = 10) {
        XCTAssertTrue(demoButton.waitForExistence(timeout: timeout), "Splash did not appear")
        demoButton.tap()
        XCTAssertTrue(trySampleButton.waitForExistence(timeout: timeout), "Demo shop did not appear")
        if let sampleShop {
            let option = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", sampleShop)).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: timeout), "\(sampleShop) option missing")
            option.tap()
        }
        trySampleButton.tap()
        XCTAssertTrue(newBillButton.waitForExistence(timeout: timeout * 2), "Home did not appear")
        // Seeding saves customers first and bills last, so a listed bill means the sample data is complete.
        let seededBill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Ravi Kumar, #D-'")).firstMatch
        XCTAssertTrue(seededBill.waitForExistence(timeout: 30), "Sample data was not seeded")
    }

    func openNewBill() {
        newBillButton.tap()
    }
}
