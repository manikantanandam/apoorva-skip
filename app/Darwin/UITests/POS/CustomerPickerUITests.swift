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

    // MARK: - Creating a customer

    func testValidPhoneAndNameEnablesAddAndAttach() {
        fillForm(phone: "9000011111", name: "Kiran Test")

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.addAndAttachButton.isEnabled)
    }

    func testAddAndAttachCreatesCustomerAndAttachesToBill() {
        fillForm(phone: "9000011111", name: "Kiran Test")
        picker.addAndAttachButton.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForNonExistence(timeout: 5), "Still walk-in after creating a customer")
        XCTAssertTrue(pos.customerRow.label.contains("Kiran Test"), "POS row shows: \(pos.customerRow.label)")
    }

    func testNewCustomerAppearsInPickerAfterCreation() {
        fillForm(phone: "9000011111", name: "Kiran Test")
        picker.addAndAttachButton.tap()
        pos.waitForScreen()
        pos.openCustomerPicker()
        picker.waitForScreen()

        XCTAssertTrue(picker.customer(named: "Kiran Test").waitForExistence(timeout: 10), "Created customer missing from list")
    }

    func testPhoneWithNineDigitsKeepsButtonDisabled() {
        fillForm(phone: "900001111", name: "Kiran Test")

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertFalse(picker.addAndAttachButton.isEnabled)
    }

    func testPhoneWithElevenDigitsKeepsButtonDisabled() {
        fillForm(phone: "90000111112", name: "Kiran Test")

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertFalse(picker.addAndAttachButton.isEnabled)
    }

    func testPhoneWithSpacesCountsOnlyDigits() {
        fillForm(phone: "90000 11111", name: "Kiran Test")

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.addAndAttachButton.isEnabled, "Ten digits with a space should be accepted")
    }

    func testLettersInPhoneKeepButtonDisabled() {
        fillForm(phone: "abcdefghij", name: "Kiran Test")

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertFalse(picker.addAndAttachButton.isEnabled)
    }

    func testPhoneWithoutNameKeepsButtonDisabled() {
        fillForm(phone: "9000011111", name: nil)

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertFalse(picker.addAndAttachButton.isEnabled)
    }

    func testNameWithoutPhoneKeepsButtonDisabled() {
        fillForm(phone: nil, name: "Kiran Test")

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertFalse(picker.addAndAttachButton.isEnabled)
    }

    func testWhitespaceOnlyNameKeepsButtonDisabled() {
        fillForm(phone: "9000011111", name: "   ")

        XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5))
        XCTAssertFalse(picker.addAndAttachButton.isEnabled)
    }

    func testExistingPhoneReusesExistingCustomer() {
        fillForm(phone: "9848012345", name: "Someone Else")
        picker.addAndAttachButton.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.customerRow.label.contains("Ravi Kumar"), "Duplicate phone should attach the existing customer: \(pos.customerRow.label)")
        XCTAssertFalse(pos.customerRow.label.contains("Someone Else"))
    }

    func testCreatedCustomerNameIsTrimmed() {
        fillForm(phone: "9000011111", name: "  Kiran Test  ")
        picker.addAndAttachButton.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.customerRow.label.contains("Kiran Test"))
    }

    // MARK: - Search edge cases

    func testSearchByPhoneFindsCustomer() {
        picker.searchField.tap()
        picker.searchField.typeText("9123456780")

        XCTAssertTrue(picker.customer(named: "Meena S").waitForExistence(timeout: 5))
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5))
    }

    func testSearchIsCaseInsensitive() {
        picker.searchField.tap()
        picker.searchField.typeText("meena")

        XCTAssertTrue(picker.customer(named: "Meena S").waitForExistence(timeout: 5))
    }

    func testSearchWithNoMatchListsNobody() {
        picker.searchField.tap()
        picker.searchField.typeText("zzzzqq")

        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5))
        XCTAssertFalse(picker.customer(named: "Meena S").exists)
        XCTAssertFalse(picker.customer(named: "Sneha P").exists)
    }

    func testUnknownPhoneInSearchPrefillsNewCustomerPhone() {
        picker.searchField.tap()
        picker.searchField.typeText("9000022222")
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5))
        dismissKeyboard()

        XCTAssertTrue(picker.phoneField.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.phoneField.value as? String, "9000022222")
    }

    func testClearingSearchRestoresFullList() {
        picker.searchField.tap()
        picker.searchField.typeText("Meena")
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5))
        picker.searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))

        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 5))
        XCTAssertTrue(picker.customer(named: "Sneha P").exists)
    }

    // MARK: - Picker navigation

    func testBackWithoutSelectingKeepsWalkIn() {
        app.buttons["BackButton"].tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.exists)
    }

    func testPickingCustomerThenReopeningAndChoosingWalkInResetsToWalkIn() {
        picker.customer(named: "Ravi Kumar").tap()
        pos.waitForScreen()
        pos.openCustomerPicker()
        picker.waitForScreen()
        picker.walkInButton.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForExistence(timeout: 5), "Walk-in should detach the previous customer")
    }

    func testSwitchingBetweenCustomersReplacesTheAttachedOne() {
        picker.customer(named: "Ravi Kumar").tap()
        pos.waitForScreen()
        pos.openCustomerPicker()
        picker.waitForScreen()
        XCTAssertTrue(picker.customer(named: "Meena S").waitForExistence(timeout: 10))
        picker.customer(named: "Meena S").tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.customerRow.label.contains("Meena S"))
        XCTAssertFalse(pos.customerRow.label.contains("Ravi Kumar"))
    }

    func testCustomerWithDuesShowsDuesInRow() {
        XCTAssertTrue(picker.customer(named: "Meena S").waitForExistence(timeout: 10))
        XCTAssertTrue(picker.customer(named: "Meena S").label.contains("dues"), "Meena has a due balance: \(picker.customer(named: "Meena S").label)")
    }

    // MARK: - Helpers

    /// Types into the new-customer form; nil leaves a field untouched. Submitting Name restores the bottom bar.
    private func fillForm(phone: String?, name: String?) {
        XCTAssertTrue(picker.phoneField.waitForExistence(timeout: 10))
        if let phone {
            picker.phoneField.tap()
            picker.phoneField.typeText(phone)
        }
        if let name {
            XCTAssertTrue(picker.nameField.waitForExistence(timeout: 5))
            picker.nameField.tap()
            picker.nameField.typeText(name + "\n")
        } else if picker.nameField.exists {
            picker.nameField.tap()
            picker.nameField.typeText("\n")
        }
        XCTAssertTrue(picker.walkInButton.waitForExistence(timeout: 5), "Bottom bar should return after submitting the form")
    }

    private func dismissKeyboard() {
        for key in ["Return", "return", "Search", "Done"] {
            let button = app.keyboards.buttons[key]
            if button.exists { button.tap(); return }
        }
    }
}
