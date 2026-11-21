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

    /// Waits for Home after `AppLauncher.launchSeeded`: seeding saves customers first and bills last, so a listed bill means the data is complete.
    func waitForSeededHome(timeout: TimeInterval = 60) {
        // The loading screen shows until seeding finishes and the session resolves; wait on Home's tab bar, not the loading view.
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: timeout), "Seeded launch stayed on the loading screen")
        XCTAssertTrue(newBillButton.waitForExistence(timeout: timeout), "Seeded Home did not appear")
        let seededBill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Ravi Kumar, #D-'")).firstMatch
        XCTAssertTrue(seededBill.waitForExistence(timeout: timeout), "Sample data was not seeded")
    }

    func openCustomersTab() {
        let tab = app.tabBars.buttons["Customers"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Customers tab missing")
        tab.tap()
    }

    func openNewBill() {
        newBillButton.firstMatch.tap() // Home has a quick action and a FAB with this label
    }
}
