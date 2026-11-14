//
//  CustomerPickerUITests.swift
//  ApoorvaUITests
//

import XCTest

@MainActor
final class CustomerPickerUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pos: POSScreen!
    private var picker: CustomerPickerScreen!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launch()
        let home = HomeScreen(app: app)
        home.enterDemoShop()
        home.openNewBill()
        pos = POSScreen(app: app)
        pos.waitForScreen()
        picker = CustomerPickerScreen(app: app)
        pos.openCustomerPicker()
        picker.waitForScreen()
    }

    func testListsSeededCustomers() {
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 10))
        XCTAssertTrue(picker.customer(named: "Meena S").exists)
    }

    func testSelectingCustomerAttachesThemToBill() {
        let ravi = picker.customer(named: "Ravi Kumar")
        XCTAssertTrue(ravi.waitForExistence(timeout: 10))
        ravi.tap()

        pos.waitForScreen()
        XCTAssertTrue(app.staticTexts["Ravi Kumar"].waitForExistence(timeout: 5))
        XCTAssertFalse(pos.walkInLabel.exists)
    }

    func testContinueAsWalkInKeepsWalkInCustomer() {
        picker.walkInButton.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForExistence(timeout: 5))
    }

    func testAddAndAttachIsDisabledUntilFormIsFilled() {
        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 10))
        XCTAssertFalse(picker.addAndAttachButton.isEnabled)
    }
}
