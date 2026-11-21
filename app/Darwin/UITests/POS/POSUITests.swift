//
//  POSUITests.swift
//  ApoorvaUITests
//
//  The whole screen is one test so the app launches and seeds once. Each scenario starts from an empty
//  walk-in bill; the scenarios that leave held bills or complete sales come last.
//

import XCTest

@MainActor
final class POSUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pos: POSScreen!

    private let bangles = "Glass Bangles"

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launchSeeded()
        let home = HomeScreen(app: app)
        home.waitForSeededHome()
        home.openNewBill()
        pos = POSScreen(app: app)
        pos.waitForScreen()
    }

    func testPOS() {
        scenario("New bill state") { newBillState() }
        scenario("Add sheet and cart editing") { addSheetAndCartEditing() }
        scenario("Find and quick item") { findAndQuickItem() }
        scenario("Bill discount") { billDiscount() }
        scenario("Hold and resume") { holdAndResume() }
        scenario("Close dialog") { closeDialog() }
        scenario("Customer on bill") { customerOnBill() }
        // Checkout is limited to basic cash/card/UPI flows: it was redesigned in #95 (per-mode amounts, no split screen),
        // so credit, split and cash-change steps are not covered.
        scenario("Checkout") { checkoutState() }
        scenario("UPI and payment modes") { upiAndPaymentModes() }
        scenario("Checkout totals") { checkoutTotals() }
        scenario("Hold from checkout") { holdFromCheckout() }
        scenario("Completed sales") { completedSales() }
    }

    // MARK: - Scenarios

    private func newBillState() {
        XCTAssertTrue(pos.walkInLabel.exists)
        XCTAssertTrue(pos.emptyCartLabel.exists)
        XCTAssertFalse(pos.checkoutButton.isEnabled, "Checkout should be disabled until an item is added")
        XCTAssertFalse(pos.holdButton.isEnabled)

        pos.heldBillsButton.tap()
        XCTAssertTrue(app.navigationBars["Held bills"].waitForExistence(timeout: 5), "Held bills screen did not open")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No held bills'")).firstMatch.exists)
    }

    private func addSheetAndCartEditing() {
        pos.addItem(named: bangles)
        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.tile(named: bangles, onBill: 1).exists, "Tile should show the quantity badge")
        XCTAssertTrue(pos.checkoutButton.isEnabled)

        pos.tile(named: bangles, onBill: 1).tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5) || pos.updateLineButton.waitForExistence(timeout: 5),
                      "A tile already on the bill still opens the sheet")

        resetToEmptyBill()
        pos.item(named: bangles).tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5))
        dismissSheet()
        XCTAssertTrue(pos.addToBillButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.exists, "Dismissing the sheet keeps the cart empty")
        XCTAssertFalse(pos.checkoutButton.isEnabled)

        pos.item(named: bangles).tap()
        XCTAssertTrue(pos.increaseQuantity.waitForExistence(timeout: 5))
        pos.increaseQuantity.tap()
        pos.increaseQuantity.tap()
        pos.addToBillButton.tap()
        XCTAssertTrue(pos.tile(named: bangles, onBill: 3).waitForExistence(timeout: 5))

        pos.item(named: "Hair Clips Set").tap()
        XCTAssertTrue(pos.decreaseQuantity.waitForExistence(timeout: 5))
        pos.decreaseQuantity.tap()
        pos.decreaseQuantity.tap()
        pos.addToBillButton.tap()
        XCTAssertTrue(pos.tile(named: "Hair Clips Set", onBill: 1).waitForExistence(timeout: 5), "Quantity must clamp at 1")

        pos.addItem(named: "Teddy 12in")
        XCTAssertTrue(app.staticTexts["3 items"].waitForExistence(timeout: 5))

        startBill()
        pos.item(named: "Hair Clips Set").tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5))
        let mrp = pos.mrpField
        mrp.tap()
        mrp.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        mrp.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertFalse(pos.addToBillButton.isEnabled, "A blank MRP must not be billable")

        startBill()
        // Tap the left of the row: its centre is not where the tap is handled.
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'pos.cartLine.'")).firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        XCTAssertTrue(pos.removeLineButton.waitForExistence(timeout: 5), "Edit sheet did not open from cart line")
        pos.removeLineButton.tap()
        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertFalse(pos.checkoutButton.isEnabled)

        startBill()
        pos.openMenu("Clear bill")
        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertFalse(pos.checkoutButton.isEnabled)
    }

    private func findAndQuickItem() {
        pos.findButton.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5) || app.textFields.firstMatch.waitForExistence(timeout: 5))
        let field = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        field.tap()
        field.typeText("Photo")
        let frame = app.buttons["Photo Frame"]
        XCTAssertTrue(frame.waitForExistence(timeout: 5))
        // The POS tile underneath has the same label, so only look at results (tiles have a `pos.tile.` identifier).
        let bangleResult = app.buttons.matching(NSPredicate(format: "label == %@ AND NOT identifier BEGINSWITH 'pos.tile.'", bangles)).firstMatch
        XCTAssertTrue(bangleResult.waitForNonExistence(timeout: 5), "Non-matching items should be filtered out")
        frame.tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5))

        resetToEmptyBill()
        pos.findButton.tap()
        let noMatchField = app.searchFields.firstMatch.waitForExistence(timeout: 5) ? app.searchFields.firstMatch : app.textFields.firstMatch
        noMatchField.tap()
        noMatchField.typeText("zzzzqq")
        XCTAssertTrue(app.staticTexts["No match"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Quick item"].exists)

        resetToEmptyBill()
        pos.openMenu("Quick item")
        XCTAssertTrue(app.navigationBars["Quick item"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add'")).firstMatch.isEnabled, "Zero amount is disabled")
        app.buttons["5"].tap()
        app.buttons["0"].tap()
        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ₹50'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.checkoutButton.isEnabled)
    }

    private func billDiscount() {
        let discountApplied = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Discount'")).firstMatch

        pos.addItem(named: bangles)
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.navigationBars["Bill discount"].waitForExistence(timeout: 5))
        pos.discountPreset(10).tap()
        pos.applyDiscountButton.tap()
        XCTAssertTrue(discountApplied.waitForExistence(timeout: 5), "Cart header should show the applied discount")
        pos.openMenu("Bill discount")
        pos.removeDiscountButton.tap()
        XCTAssertTrue(app.buttons["Add discount"].waitForExistence(timeout: 5))

        startBill()
        pos.openMenu("Bill discount")
        let round = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Round to'")).firstMatch
        XCTAssertTrue(round.waitForExistence(timeout: 5), "Rs 120 should offer a round-down chip")
        round.tap()
        pos.applyDiscountButton.tap()
        XCTAssertTrue(discountApplied.waitForExistence(timeout: 5))

        startBill()
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.buttons["₹ amount"].waitForExistence(timeout: 5))
        app.buttons["₹ amount"].tap()
        pos.key("5").tap()
        pos.applyDiscountButton.tap()
        XCTAssertTrue(discountApplied.waitForExistence(timeout: 5))
        // The manager-PIN steps (90% needs approval, wrong PIN, lowering the discount) are not covered: the seeded
        // user is an owner, who never needs approval.
    }

    private func holdAndResume() {
        pos.addItem(named: bangles)
        XCTAssertTrue(pos.holdButton.isEnabled)
        pos.holdButton.tap()
        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Held bills (1)"].waitForExistence(timeout: 5))

        pos.addItem(named: "Teddy 12in")
        pos.holdButton.tap()
        XCTAssertTrue(pos.heldBillsButton.waitForExistence(timeout: 5))
        pos.heldBillsButton.tap()
        XCTAssertTrue(app.navigationBars["Held bills"].waitForExistence(timeout: 5))
        // Rows only (they end in ", Held"); tap the left side, as the row's centre doesn't take the tap on device.
        app.buttons.matching(NSPredicate(format: "label ENDSWITH ', Held'")).element(boundBy: 0)
            .coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.emptyCartLabel.waitForNonExistence(timeout: 5), "Resuming restores the cart")
    }

    private func closeDialog() {
        let home = HomeScreen(app: app)

        closeBill()
        XCTAssertTrue(home.newBillButton.waitForExistence(timeout: 10), "Closing an empty cart leaves immediately")
        home.openNewBill()
        pos.waitForScreen()
        // Earlier scenarios may have held bills, so compare against the count now instead of assuming zero.
        let heldBefore = heldCount()

        pos.addItem(named: bangles)
        closeBill()
        XCTAssertTrue(app.buttons["Discard bill"].waitForExistence(timeout: 5), "Unsaved-bill dialog did not appear")
        XCTAssertTrue(app.sheets.firstMatch.buttons["Hold bill"].exists)
        keepBilling()
        XCTAssertTrue(app.buttons["Discard bill"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.tile(named: bangles, onBill: 1).exists, "Keep billing leaves the cart intact")

        closeBill()
        XCTAssertTrue(app.buttons["Discard bill"].waitForExistence(timeout: 5))
        app.buttons["Discard bill"].tap()
        XCTAssertTrue(home.newBillButton.waitForExistence(timeout: 10))
        home.openNewBill()
        pos.waitForScreen()
        XCTAssertTrue(pos.emptyCartLabel.exists, "Discarded cart must not come back")
        XCTAssertEqual(heldCount(), heldBefore, "Discard must not park the bill")

        pos.addItem(named: bangles)
        closeBill()
        XCTAssertTrue(app.sheets.firstMatch.buttons["Hold bill"].waitForExistence(timeout: 5))
        app.sheets.firstMatch.buttons["Hold bill"].tap()
        XCTAssertTrue(home.newBillButton.waitForExistence(timeout: 10))
        home.openNewBill()
        pos.waitForScreen()
        XCTAssertTrue(pos.emptyCartLabel.exists)
        XCTAssertEqual(heldCount(), heldBefore + 1, "Held count: \(pos.heldBillsButton.label)")
    }

    private func customerOnBill() {
        attachCustomer(named: "Meena S")
        pos.addItem(named: bangles)
        XCTAssertTrue(pos.customerRow.label.contains("Meena S"), "Customer stays attached after adding an item")
    }

    private func checkoutState() {
        pos.addItem(named: bangles)
        pos.openCheckout()
        XCTAssertTrue(app.staticTexts["Walk-in customer"].exists)
        XCTAssertTrue(app.staticTexts["Payment"].exists)
        for mode in ["Cash", "UPI", "Card"] {
            XCTAssertTrue(pos.paymentMode(mode).exists, "\(mode) chip missing")
        }
        XCTAssertTrue(pos.collectButton.isEnabled)

        app.buttons["BackButton"].tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.tile(named: bangles, onBill: 1).exists, "Back from checkout keeps the cart")

        startBill()
        attachCustomer(named: "Ravi Kumar")
        pos.addItem(named: bangles)
        pos.openCheckout()
        XCTAssertTrue(pos.checkoutCustomerRow.label.contains("Ravi Kumar"), "Checkout row: \(pos.checkoutCustomerRow.label)")
        XCTAssertFalse(app.staticTexts["Walk-in customer"].exists)
    }

    private func upiAndPaymentModes() {
        pos.addItem(named: bangles)
        pos.openCheckout()
        for mode in ["Card", "UPI", "Cash"] {
            pos.paymentMode(mode).tap()
            XCTAssertTrue(pos.collectButton.isEnabled, "Collect disabled on \(mode)")
        }

        enterAmount("120", mode: "UPI")
        pos.collectButton.tap()
        XCTAssertTrue(pos.upiChangeMode.waitForExistence(timeout: 5))
        pos.upiChangeMode.tap()
        XCTAssertTrue(app.navigationBars["Checkout"].waitForExistence(timeout: 5))
        XCTAssertTrue(pos.collectButton.exists, "Change mode returns to checkout with the cart intact")

        pos.collectButton.tap()
        XCTAssertTrue(app.navigationBars["Pay by UPI"].waitForExistence(timeout: 5))
        app.buttons["BackButton"].tap()
        XCTAssertTrue(app.navigationBars["Checkout"].waitForExistence(timeout: 5))
        XCTAssertFalse(pos.receiptHome.exists, "Back from the UPI screen does not complete the sale")
    }

    private func checkoutTotals() {
        pos.addItem(named: bangles)
        pos.openCheckout()
        let single = pos.collectButton.label
        app.buttons["BackButton"].tap()
        pos.waitForScreen()
        pos.addItem(named: "Hair Clips Set")
        pos.openCheckout()
        XCTAssertNotEqual(pos.collectButton.label, single, "Two items increase the collect amount")

        startBill()
        pos.openCheckout()
        let before = pos.collectButton.label
        app.buttons["BackButton"].tap()
        pos.waitForScreen()
        pos.openMenu("Bill discount")
        pos.discountPreset(10).tap()
        pos.applyDiscountButton.tap()
        pos.openCheckout()
        XCTAssertNotEqual(pos.collectButton.label, before, "Collect amount should drop after a 10% discount")
        XCTAssertTrue(app.staticTexts["Discount"].exists, "Discount row missing in summary")
    }

    private func holdFromCheckout() {
        pos.addItem(named: bangles)
        pos.openCheckout()
        pos.checkoutHoldButton.tap()
        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 10) || pos.customerRow.waitForExistence(timeout: 10))
    }

    private func completedSales() {
        pos.addItem(named: bangles)
        pos.openCheckout()
        pos.collectButton.tap()
        XCTAssertTrue(pos.receiptHome.waitForExistence(timeout: 15), "Receipt did not appear after collecting")
        XCTAssertTrue(pos.receiptNewBill.exists)
        XCTAssertFalse(app.buttons[AccessibilityID.Receipt.editBill].exists, "Edit bill is hidden right after checkout")
        pos.receiptNewBill.tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.exists)
        XCTAssertTrue(pos.emptyCartLabel.exists, "New bill after a sale must start empty")
        XCTAssertFalse(pos.checkoutButton.isEnabled)
        XCTAssertFalse(pos.tile(named: bangles, onBill: 1).exists)

        startBill()
        pos.openCheckout()
        enterAmount("120", mode: "Card")
        pos.completeCashSale()

        startBill()
        pos.openCheckout()
        enterAmount("120", mode: "UPI")
        pos.collectButton.tap()
        XCTAssertTrue(app.navigationBars["Pay by UPI"].waitForExistence(timeout: 5), "UPI screen did not open")
        XCTAssertTrue(pos.upiMarkReceived.exists)
        pos.upiMarkReceived.tap()
        XCTAssertTrue(pos.receiptHome.waitForExistence(timeout: 15))

        resetToEmptyBill()
        attachCustomer(named: "Ravi Kumar")
        pos.addItem(named: bangles)
        pos.openCheckout()
        pos.completeCashSale()
        pos.receiptNewBill.tap()
        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.waitForExistence(timeout: 5), "Next bill should start as walk-in")

        startBill()
        pos.openCheckout()
        pos.completeCashSale()
        pos.receiptHome.tap()
        XCTAssertTrue(HomeScreen(app: app).newBillButton.waitForExistence(timeout: 10))
    }

    // MARK: - Helpers

    private func scenario(_ name: String, _ body: () -> Void) {
        XCTContext.runActivity(named: name) { _ in
            resetToEmptyBill()
            body()
        }
    }

    /// Resets, then puts one item on the bill.
    private func startBill() {
        resetToEmptyBill()
        pos.addItem(named: bangles)
    }

    /// Back to the POS screen on an empty walk-in bill, whatever screen, sheet or dialog the last step left open.
    private func resetToEmptyBill() {
        let home = HomeScreen(app: app)
        for _ in 0..<6 {
            if pos.receiptNewBill.exists { pos.receiptNewBill.tap(); continue }
            if app.buttons["Discard bill"].exists { keepBilling(); continue }
            if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap(); continue }
            let dateSheet = app.navigationBars["Bill date & time"]
            if dateSheet.exists {
                let done = dateSheet.buttons.firstMatch
                if done.exists { done.tap() } else { dateSheet.swipeDown() }
                continue
            }
            // Half sheets leave the POS row hittable, so close them before the "already on POS" check.
            if wideCloseButtons().count >= 2 { dismissSheet(); continue }
            if !pos.customerRow.exists && home.newBillButton.exists { home.openNewBill(); continue }
            if pos.customerRow.exists && pos.customerRow.isHittable { break }
            if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap(); continue }
        }
        pos.waitForScreen()
        if !pos.walkInLabel.exists {
            pos.openCustomerPicker()
            let picker = CustomerPickerScreen(app: app)
            picker.waitForScreen()
            picker.walkInButton.tap()
            pos.waitForScreen()
        }
        if pos.checkoutButton.isEnabled { pos.openMenu("Clear bill") }
        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5), "Bill did not reset to empty")
        XCTAssertTrue(pos.addToBillButton.waitForNonExistence(timeout: 5), "A sheet is still open after reset")
    }

    /// The number in the "Held bills (n)" button.
    private func heldCount() -> Int {
        let digits = pos.heldBillsButton.label.filter(\.isNumber)
        return Int(digits) ?? -1
    }

    /// Pays the whole bill (one Glass Bangles, Rs 120) in `mode`. Nothing typed means all cash, so card and UPI need an amount.
    private func enterAmount(_ amount: String, mode: String) {
        pos.paymentMode(mode).tap()
        pos.cashReceivedField.tap()
        pos.cashReceivedField.typeText(amount)
        for key in ["Done", "Return"] where app.keyboards.buttons[key].exists {
            app.keyboards.buttons[key].tap()
            break
        }
    }

    /// The unsaved-bill dialog's "Keep billing" shows up as a full-size "Close" button after the POS screen's own.
    private func keepBilling() {
        wideCloseButtons().last?.tap()
    }

    /// The POS screen's Close button (cart lines have a tiny remove button with the same label).
    private func closeBill() {
        wideCloseButtons().first?.tap()
    }

    private func wideCloseButtons() -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label == 'Close'")).allElementsBoundByIndex.filter { $0.frame.width > 30 }
    }

    /// Closes the open sheet with its Close button. The sheets are full height, so a swipe doesn't dismiss them
    /// reliably; the sheet's Close is the lowest on screen (the POS screen underneath has its own at the very top).
    private func dismissSheet() {
        wideCloseButtons().max(by: { $0.frame.minY < $1.frame.minY })?.tap()
    }

    private func attachCustomer(named name: String) {
        pos.openCustomerPicker()
        let picker = CustomerPickerScreen(app: app)
        picker.waitForScreen()
        let row = picker.customer(named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Seeded customers did not load")
        row.tap()
        pos.waitForScreen()
    }
}

private extension XCUIElement {
    func tapIfExists() { if exists { tap() } }
}
