//
//  CustomerPickerUITests.swift
//  ApoorvaUITests
//
//  The whole screen is one test so the app launches and seeds once. Each scenario starts on a freshly opened
//  picker with a walk-in bill; the scenarios that create customers come last.
//

import XCTest

@MainActor
final class CustomerPickerUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pos: POSScreen!
    private var picker: CustomerPickerScreen!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launchSeeded()
        let home = HomeScreen(app: app)
        home.waitForSeededHome()
        home.openNewBill()
        pos = POSScreen(app: app)
        pos.waitForScreen()
        picker = CustomerPickerScreen(app: app)
    }

    func testCustomerPicker() {
        scenario("Seeded customers and dues") { seededCustomers() }
        scenario("Search") { search() }
        scenario("Focus-driven visibility") { focusVisibility() }
        scenario("Form validation") { formValidation() }
        scenario("Attaching customers") { attachingCustomers() }
        scenario("Creating customers") { creatingCustomers() }
    }

    // MARK: - Scenarios

    private func seededCustomers() {
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 10))
        XCTAssertTrue(picker.customer(named: "Meena S").exists)
        XCTAssertTrue(picker.customer(named: "Meena S").label.contains("dues"), "Meena has a due balance: \(picker.customer(named: "Meena S").label)")
        XCTAssertTrue(picker.addAndAttachButton.exists)
        XCTAssertFalse(picker.addAndAttachButton.isEnabled, "Add & attach is disabled until the form is filled")
    }

    private func search() {
        searchFor("Meena")
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5), "Ravi still listed after search")
        XCTAssertTrue(picker.customer(named: "Meena S").exists)
        picker.searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 5), "Clearing search restores the list")
        XCTAssertTrue(picker.customer(named: "Sneha P").exists)

        resetPicker()
        searchFor("9123456780")
        XCTAssertTrue(picker.customer(named: "Meena S").waitForExistence(timeout: 5))
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5))

        resetPicker()
        searchFor("meena")
        XCTAssertTrue(picker.customer(named: "Meena S").waitForExistence(timeout: 5), "Search is case-insensitive")

        resetPicker()
        searchFor("zzzzqq")
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5))
        XCTAssertFalse(picker.customer(named: "Meena S").exists)
        XCTAssertFalse(picker.customer(named: "Sneha P").exists)

        resetPicker()
        searchFor("9000022222")
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForNonExistence(timeout: 5))
        dismissKeyboard()
        XCTAssertTrue(picker.phoneField.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.phoneField.value as? String, "9000022222", "Unknown phone prefills the new customer form")
    }

    private func focusVisibility() {
        XCTAssertTrue(picker.recentHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(picker.searchField.exists)
        XCTAssertTrue(picker.newCustomerHeader.exists)
        XCTAssertTrue(picker.phoneField.exists)
        XCTAssertTrue(picker.walkInButton.exists)
        XCTAssertTrue(picker.addAndAttachButton.exists)

        picker.searchField.tap()
        XCTAssertTrue(picker.newCustomerHeader.waitForNonExistence(timeout: 5), "New customer header still shown")
        XCTAssertFalse(picker.phoneField.exists)
        XCTAssertFalse(picker.nameField.exists)
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").exists, "Results should stay visible while searching")
        XCTAssertFalse(picker.recentHeader.exists, "Recent hides once the search is focused")

        resetPicker()
        picker.phoneField.tap()
        XCTAssertTrue(picker.searchField.waitForNonExistence(timeout: 5), "Search still shown")
        XCTAssertFalse(picker.customer(named: "Ravi Kumar").exists)
        XCTAssertFalse(picker.recentHeader.exists)
        XCTAssertFalse(picker.walkInButton.exists)
        XCTAssertFalse(picker.addAndAttachButton.exists)
        XCTAssertTrue(picker.phoneField.exists)
        XCTAssertTrue(picker.nameField.exists)

        resetPicker()
        picker.nameField.tap()
        XCTAssertTrue(picker.searchField.waitForNonExistence(timeout: 5), "Search still shown")
        XCTAssertFalse(picker.customer(named: "Ravi Kumar").exists)
        XCTAssertFalse(picker.walkInButton.exists)
        XCTAssertFalse(picker.addAndAttachButton.exists)

        picker.nameField.typeText("\n")
        XCTAssertTrue(picker.walkInButton.waitForExistence(timeout: 5), "Bottom bar should return after Done")
        XCTAssertTrue(picker.searchField.exists)
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").exists)
    }

    private func formValidation() {
        let cases: [(phone: String?, name: String?, enabled: Bool, why: String)] = [
            ("9000011111", "Kiran Test", true, "valid phone and name"),
            ("900001111", "Kiran Test", false, "nine digits"),
            ("90000111112", "Kiran Test", false, "eleven digits"),
            ("90000 11111", "Kiran Test", true, "ten digits with a space"),
            ("abcdefghij", "Kiran Test", false, "letters in phone"),
            ("9000011111", nil, false, "phone without name"),
            (nil, "Kiran Test", false, "name without phone"),
            ("9000011111", "   ", false, "whitespace-only name")
        ]
        for (index, testCase) in cases.enumerated() {
            if index > 0 { resetPicker() }
            fillForm(phone: testCase.phone, name: testCase.name)
            XCTAssertTrue(picker.addAndAttachButton.waitForExistence(timeout: 5), testCase.why)
            XCTAssertEqual(picker.addAndAttachButton.isEnabled, testCase.enabled, testCase.why)
        }
    }

    private func attachingCustomers() {
        let chip = picker.recentChip(named: "Ravi Kumar")
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.customerRow.label.contains("Ravi Kumar"), "Recent chip attaches: \(pos.customerRow.label)")

        resetPicker()
        picker.customer(named: "Meena S").tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.customerRow.label.contains("Meena S"), "Picking a customer attaches them: \(pos.customerRow.label)")
        XCTAssertFalse(pos.customerRow.label.contains("Ravi Kumar"), "Switching replaces the attached customer")

        pos.openCustomerPicker()
        picker.waitForScreen()
        picker.walkInButton.tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForExistence(timeout: 5), "Walk-in detaches the previous customer")

        pos.openCustomerPicker()
        picker.waitForScreen()
        app.buttons["BackButton"].tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.exists, "Back without selecting keeps walk-in")
    }

    private func creatingCustomers() {
        fillForm(phone: "9000011111", name: "Kiran Test")
        picker.addAndAttachButton.tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForNonExistence(timeout: 5), "Still walk-in after creating a customer")
        XCTAssertTrue(pos.customerRow.label.contains("Kiran Test"), "POS row shows: \(pos.customerRow.label)")

        pos.openCustomerPicker()
        picker.waitForScreen()
        XCTAssertTrue(picker.customer(named: "Kiran Test").waitForExistence(timeout: 10), "Created customer missing from list")

        resetPicker()
        fillForm(phone: "9848012345", name: "Someone Else")
        picker.addAndAttachButton.tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.customerRow.label.contains("Ravi Kumar"), "Duplicate phone should attach the existing customer: \(pos.customerRow.label)")
        XCTAssertFalse(pos.customerRow.label.contains("Someone Else"))

        resetPicker()
        fillForm(phone: "9000033333", name: "  Kiran Trim  ")
        picker.addAndAttachButton.tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.customerRow.label.contains("Kiran Trim"), "Name is trimmed: \(pos.customerRow.label)")
    }

    // MARK: - Helpers

    private func scenario(_ name: String, _ body: () -> Void) {
        XCTContext.runActivity(named: name) { _ in
            resetPicker()
            body()
        }
    }

    /// Opens a fresh picker on a walk-in bill.
    private func resetPicker() {
        dismissKeyboard()
        if picker.title.exists { app.buttons["BackButton"].tap() }
        pos.waitForScreen()
        if !pos.walkInLabel.exists {
            pos.openCustomerPicker()
            picker.waitForScreen()
            picker.walkInButton.tap()
            pos.waitForScreen()
        }
        // The picker loads once on appear, so reopen it until the seeded customers show.
        for attempt in 1...4 {
            pos.openCustomerPicker()
            picker.waitForScreen()
            if picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 8) { return }
            if attempt < 4 { app.buttons["BackButton"].tap(); pos.waitForScreen() }
        }
        XCTFail("Seeded customers did not load")
    }

    private func searchFor(_ text: String) {
        XCTAssertTrue(picker.customer(named: "Ravi Kumar").waitForExistence(timeout: 10))
        picker.searchField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keyboard did not appear")
        picker.searchField.typeText(text)
    }

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
