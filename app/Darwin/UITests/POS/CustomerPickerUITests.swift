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
        // Demo data is seeded asynchronously and the picker loads once on appear, so reopen it until the customers show.
        for attempt in 1...4 {
            pos.openCustomerPicker()
            picker.waitForScreen()
            if picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 8) { return }
            if attempt < 4 { app.buttons["BackButton"].tap(); pos.waitForScreen() }
        }
        XCTFail("Seeded customers did not load")
    }

    func testListsSeededCustomers() {
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 10))
        XCTAssertTrue(picker.customer(named: "Meena S").exists)
    }

    func testSearchFiltersCustomers() {
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 10))
        picker.searchField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keyboard did not appear")
        picker.searchField.typeText("Meena")

        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5), "Ravi still listed after search")
        XCTAssertTrue(picker.customer(named: "Meena S").exists)
    }

    func testTappingRecentChipAttachesCustomer() {
        let chip = picker.recentChip(named: "Ravi Kumar")
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.customerRow.label.contains("Ravi Kumar"))
    }

    func testSelectingCustomerAttachesThemToBill() {
        let ravi = picker.customer(named: "Ravi Kumar")
        XCTAssertTrue(ravi.waitForExistence(timeout: 10))
        ravi.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForNonExistence(timeout: 5), "Still walk-in after picking a customer")
        XCTAssertTrue(pos.customerRow.label.contains("Ravi Kumar"), "POS row shows: \(pos.customerRow.label)")
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

    // MARK: - Focus-driven visibility

    func testDefaultStateShowsEverything() {
        XCTAssertTrue(picker.recentHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(picker.searchField.exists)
        XCTAssertTrue(picker.newCustomerHeader.exists)
        XCTAssertTrue(picker.phoneField.exists)
        XCTAssertTrue(picker.walkInButton.exists)
        XCTAssertTrue(picker.addAndAttachButton.exists)
    }

    func testFocusingSearchHidesNewCustomerForm() {
        XCTAssertTrue(picker.recentHeader.waitForExistence(timeout: 10))
        picker.searchField.tap()

        XCTAssertTrue(picker.newCustomerHeader.waitForNonExistence(timeout: 5), "New customer header still shown")
        XCTAssertFalse(picker.phoneField.exists)
        XCTAssertFalse(picker.nameField.exists)
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").exists, "Results should stay visible while searching")
        XCTAssertFalse(picker.recentHeader.exists, "Recent hides once the search is focused")
    }

    func testFocusingPhoneHidesSearchListAndBottomBar() {
        XCTAssertTrue(picker.phoneField.waitForExistence(timeout: 10))
        picker.phoneField.tap()

        XCTAssertTrue(picker.searchField.waitForNonExistence(timeout: 5), "Search still shown")
        XCTAssertFalse(picker.customer(named: "Ravi Kumar").exists)
        XCTAssertFalse(picker.recentHeader.exists)
        XCTAssertFalse(picker.walkInButton.exists)
        XCTAssertFalse(picker.addAndAttachButton.exists)
        XCTAssertTrue(picker.phoneField.exists)
        XCTAssertTrue(picker.nameField.exists)
    }

    func testFocusingNameHidesSearchListAndBottomBar() {
        XCTAssertTrue(picker.nameField.waitForExistence(timeout: 10))
        picker.nameField.tap()

        XCTAssertTrue(picker.searchField.waitForNonExistence(timeout: 5), "Search still shown")
        XCTAssertFalse(picker.customer(named: "Ravi Kumar").exists)
        XCTAssertFalse(picker.walkInButton.exists)
        XCTAssertFalse(picker.addAndAttachButton.exists)
    }

    func testSubmittingNameRestoresFullLayout() {
        XCTAssertTrue(picker.nameField.waitForExistence(timeout: 10))
        picker.nameField.tap()
        picker.nameField.typeText("\n")

        XCTAssertTrue(picker.walkInButton.waitForExistence(timeout: 5), "Bottom bar should return after Done")
        XCTAssertTrue(picker.searchField.exists)
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").exists)
    }
}
