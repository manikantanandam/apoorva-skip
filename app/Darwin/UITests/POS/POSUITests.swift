//
//  POSUITests.swift
//  ApoorvaUITests
//

import XCTest

@MainActor
final class POSUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pos: POSScreen!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launch()
        let home = HomeScreen(app: app)
        home.enterDemoShop()
        home.openNewBill()
        pos = POSScreen(app: app)
        pos.waitForScreen()
    }

    func testNewBillStartsAsWalkInWithEmptyCart() {
        XCTAssertTrue(pos.walkInLabel.exists)
        XCTAssertTrue(pos.emptyCartLabel.exists)
        XCTAssertFalse(pos.checkoutButton.isEnabled, "Checkout should be disabled until an item is added")
    }
}
