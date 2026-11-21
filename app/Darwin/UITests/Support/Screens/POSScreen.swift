//
//  POSScreen.swift
//  ApoorvaUITests
//
//  Page object for the New bill (POS) screen.
//

import XCTest

@MainActor
struct POSScreen {
    let app: XCUIApplication

    var customerRow: XCUIElement { app.buttons[AccessibilityID.Pos.customerRow] }
    var walkInLabel: XCUIElement { app.staticTexts["Walk-in customer"] }
    var emptyCartLabel: XCUIElement { app.staticTexts["Your cart is empty"] }
    var checkoutButton: XCUIElement { app.buttons[AccessibilityID.Pos.checkout] }

    var currentCartHeader: XCUIElement { app.staticTexts["Current cart"] }
    var findButton: XCUIElement { app.buttons[AccessibilityID.Pos.find] }
    var holdButton: XCUIElement { app.buttons[AccessibilityID.Pos.holdBill] }
    var heldBillsButton: XCUIElement { app.buttons[AccessibilityID.Pos.heldBills] }
    var dateButton: XCUIElement { app.buttons[AccessibilityID.Pos.billDate] }
    var moreMenu: XCUIElement { app.buttons[AccessibilityID.Pos.moreMenu] }

    // Add-line half sheet (the save button reads "Add to bill" or "Update line")
    var addToBillButton: XCUIElement { app.buttons[AccessibilityID.QuickAddLine.save] }
    var updateLineButton: XCUIElement { app.buttons[AccessibilityID.QuickAddLine.save] }
    var removeLineButton: XCUIElement { app.buttons[AccessibilityID.QuickAddLine.remove] }
    var increaseQuantity: XCUIElement { app.buttons[AccessibilityID.QuickAddLine.increase] }
    var decreaseQuantity: XCUIElement { app.buttons[AccessibilityID.QuickAddLine.decrease] }
    var mrpField: XCUIElement { app.textFields[AccessibilityID.QuickAddLine.mrp] }
    var discountField: XCUIElement { app.textFields[AccessibilityID.QuickAddLine.discount] }

    func cartLines() -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'pos.cartLine.'"))
    }

    // Checkout / receipt
    var collectButton: XCUIElement { app.buttons[AccessibilityID.Checkout.collect] }
    var checkoutHoldButton: XCUIElement { app.buttons[AccessibilityID.Checkout.hold] }
    var cashReceivedField: XCUIElement { app.textFields[AccessibilityID.Checkout.cashReceived] }
    var splitPrimaryButton: XCUIElement { app.buttons[AccessibilityID.SplitPayment.primary] }
    var receiptHome: XCUIElement { app.buttons[AccessibilityID.Receipt.home] }
    var receiptNewBill: XCUIElement { app.buttons[AccessibilityID.Receipt.newBill] }

    // Bill discount
    var applyDiscountButton: XCUIElement { app.buttons[AccessibilityID.BillDiscount.apply] }
    var removeDiscountButton: XCUIElement { app.buttons[AccessibilityID.BillDiscount.remove] }
    func discountPreset(_ percent: Int) -> XCUIElement { app.buttons[AccessibilityID.BillDiscount.preset(percent)] }

    var checkoutCustomerRow: XCUIElement { app.buttons[AccessibilityID.Checkout.customerRow] }
    var upiMarkReceived: XCUIElement { app.buttons[AccessibilityID.UPI.markReceived] }
    var upiChangeMode: XCUIElement { app.buttons[AccessibilityID.UPI.changeMode] }

    /// Keypad key on the split/quick-item screens (labelled by its digit).
    func key(_ digit: String) -> XCUIElement { app.buttons[digit] }

    /// Segment inside the split screen; excludes the checkout chip of the same name.
    func splitSegment(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ AND NOT identifier BEGINSWITH 'checkout.mode.'", title)).firstMatch
    }

    /// Finishes a cash sale and waits for the receipt.
    func completeCashSale() {
        collectButton.tap()
        XCTAssertTrue(receiptHome.waitForExistence(timeout: 15), "Receipt did not appear after collecting")
    }

    /// The app builds the id from the mode's raw value, which is lowercase ("cash", "upi", ...).
    func paymentMode(_ name: String) -> XCUIElement { app.buttons[AccessibilityID.Checkout.mode(name.lowercased())] }
    var creditNote: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Checkout.creditNote] }
    var changeDue: XCUIElement { app.descendants(matching: .any)[AccessibilityID.Checkout.changeDue] }

    func item(named name: String) -> XCUIElement { app.buttons[AccessibilityID.Pos.tile(name)] }

    /// Tile label gains ", N on bill" once the item is on the cart.
    func tile(named name: String, onBill quantity: Int) -> XCUIElement { app.buttons["\(name), \(quantity) on bill"] }

    func openMenu(_ entry: String) {
        moreMenu.tap()
        let item = app.buttons[entry]
        // A tap right after a sheet closes can be swallowed, so retry once before failing.
        if !item.waitForExistence(timeout: 2) { moreMenu.tap() }
        XCTAssertTrue(item.waitForExistence(timeout: 5), "\(entry) missing from the More menu")
        item.tap()
    }

    /// Tap a quick tile, then confirm the add-line sheet with its defaults.
    func addItem(named name: String) {
        item(named: name).tap()
        XCTAssertTrue(addToBillButton.waitForExistence(timeout: 5), "Add-line sheet did not open for \(name)")
        addToBillButton.tap()
        XCTAssertTrue(addToBillButton.waitForNonExistence(timeout: 5), "Add-line sheet did not close")
    }

    func openCheckout() {
        XCTAssertTrue(checkoutButton.isEnabled, "Checkout should be enabled")
        checkoutButton.tap()
        XCTAssertTrue(app.navigationBars["Checkout"].waitForExistence(timeout: 5), "Checkout did not open")
    }

    func waitForScreen(timeout: TimeInterval = 10) {
        XCTAssertTrue(customerRow.waitForExistence(timeout: timeout), "POS screen did not appear")
    }

    func openCustomerPicker() {
        customerRow.tap()
    }
}
