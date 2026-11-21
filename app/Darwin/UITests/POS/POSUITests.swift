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

    // MARK: - Adding items

    func testTappingTileOpensAddSheetAndAddsToCart() {
        pos.addItem(named: "Glass Bangles")

        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.tile(named: "Glass Bangles", onBill: 1).exists, "Tile should show the quantity badge")
        XCTAssertTrue(pos.checkoutButton.isEnabled)
    }

    func testDismissingAddSheetWithoutSavingKeepsCartEmpty() {
        pos.item(named: "Glass Bangles").tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5))
        app.swipeDown()

        XCTAssertTrue(pos.addToBillButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.exists)
        XCTAssertFalse(pos.checkoutButton.isEnabled)
    }

    func testIncreasingQuantityInAddSheetUpdatesBadge() {
        pos.item(named: "Glass Bangles").tap()
        XCTAssertTrue(pos.increaseQuantity.waitForExistence(timeout: 5))
        pos.increaseQuantity.tap()
        pos.increaseQuantity.tap()
        pos.addToBillButton.tap()

        XCTAssertTrue(pos.tile(named: "Glass Bangles", onBill: 3).waitForExistence(timeout: 5))
    }

    func testQuantityCannotGoBelowOne() {
        pos.item(named: "Glass Bangles").tap()
        XCTAssertTrue(pos.decreaseQuantity.waitForExistence(timeout: 5))
        pos.decreaseQuantity.tap()
        pos.decreaseQuantity.tap()
        pos.addToBillButton.tap()

        XCTAssertTrue(pos.tile(named: "Glass Bangles", onBill: 1).waitForExistence(timeout: 5), "Quantity must clamp at 1")
    }

    func testAddingDifferentItemsShowsItemCount() {
        pos.addItem(named: "Glass Bangles")
        pos.addItem(named: "Teddy 12in")

        XCTAssertTrue(app.staticTexts["2 items"].waitForExistence(timeout: 5))
        XCTAssertTrue(pos.tile(named: "Teddy 12in", onBill: 1).exists)
    }

    func testClearingMrpDisablesAddToBill() {
        pos.item(named: "Glass Bangles").tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5))
        let mrp = pos.mrpField
        mrp.tap()
        mrp.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        mrp.typeText(XCUIKeyboardKey.delete.rawValue)

        XCTAssertFalse(pos.addToBillButton.isEnabled, "A blank MRP must not be billable")
    }

    // MARK: - Editing the cart

    func testTappingTileForItemAlreadyOnBillStillOpensSheet() {
        pos.addItem(named: "Glass Bangles")
        pos.tile(named: "Glass Bangles", onBill: 1).tap()

        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5) || pos.updateLineButton.waitForExistence(timeout: 5))
    }

    func testRemovingLineFromEditSheetEmptiesCart() {
        pos.addItem(named: "Glass Bangles")
        pos.cartLines().firstMatch.tap()
        XCTAssertTrue(pos.removeLineButton.waitForExistence(timeout: 5), "Edit sheet did not open from cart line")
        pos.removeLineButton.tap()

        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertFalse(pos.checkoutButton.isEnabled)
    }

    func testClearBillMenuEmptiesCart() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Clear bill")

        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertFalse(pos.checkoutButton.isEnabled)
    }

    func testClearBillMenuEntryHiddenWhenCartEmpty() {
        pos.moreMenu.tap()
        XCTAssertTrue(app.buttons["Quick item"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Clear bill"].exists)
    }

    // MARK: - Find

    func testFindOpensSearchSheetAndAddsItem() {
        pos.findButton.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5) || app.textFields.firstMatch.waitForExistence(timeout: 5))
        let field = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        field.tap()
        field.typeText("Photo")

        let frame = app.buttons["Photo Frame"]
        XCTAssertTrue(frame.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Glass Bangles"].waitForNonExistence(timeout: 5), "Non-matching items should be filtered out")
        frame.tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5))
    }

    func testFindWithNoMatchShowsEmptyStateWithQuickItem() {
        pos.findButton.tap()
        let field = app.searchFields.firstMatch.waitForExistence(timeout: 5) ? app.searchFields.firstMatch : app.textFields.firstMatch
        field.tap()
        field.typeText("zzzzqq")

        XCTAssertTrue(app.staticTexts["No match"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Quick item"].exists)
    }

    // MARK: - Quick (custom) item

    func testQuickItemWithZeroAmountIsDisabled() {
        pos.openMenu("Quick item")
        XCTAssertTrue(app.navigationBars["Quick item"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add'")).firstMatch.isEnabled)
    }

    func testQuickItemAddsCustomLineToCart() {
        pos.openMenu("Quick item")
        XCTAssertTrue(app.navigationBars["Quick item"].waitForExistence(timeout: 5))
        app.buttons["5"].tap()
        app.buttons["0"].tap()
        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add ₹50'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.checkoutButton.isEnabled)
    }

    // MARK: - Bill discount

    func testBillDiscountPresetAppliesAndCanBeRemoved() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.navigationBars["Bill discount"].waitForExistence(timeout: 5))
        pos.discountPreset(10).tap()
        pos.applyDiscountButton.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Discount'")).firstMatch.waitForExistence(timeout: 5),
                      "Cart header should show the applied discount")

        pos.openMenu("Bill discount")
        pos.removeDiscountButton.tap()
        XCTAssertTrue(app.buttons["Add discount"].waitForExistence(timeout: 5))
    }

    func testBillDiscountApplyDisabledWithoutValue() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.navigationBars["Bill discount"].waitForExistence(timeout: 5))

        XCTAssertFalse(pos.applyDiscountButton.isEnabled)
    }

    func testBillDiscountAboveLimitRequiresManagerPin() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.navigationBars["Bill discount"].waitForExistence(timeout: 5))
        app.buttons["%"].tap()
        for key in ["9", "0"] { app.buttons[key].tap() }

        XCTAssertTrue(app.staticTexts["Manager PIN"].waitForExistence(timeout: 5), "90% should need manager approval")
        XCTAssertFalse(pos.applyDiscountButton.isEnabled)
    }

    // MARK: - Hold / resume

    func testHoldButtonDisabledWhenCartEmpty() {
        XCTAssertFalse(pos.holdButton.isEnabled)
    }

    func testHoldingBillClearsCartAndShowsHeldIndicator() {
        pos.addItem(named: "Glass Bangles")
        XCTAssertTrue(pos.holdButton.isEnabled)
        pos.holdButton.tap()

        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Held bills (1)"].waitForExistence(timeout: 5))
    }

    func testHeldBillsEmptyState() {
        pos.heldBillsButton.tap()

        XCTAssertTrue(app.staticTexts["No held bills"].waitForExistence(timeout: 5))
    }

    func testResumingHeldBillRestoresCart() {
        pos.addItem(named: "Teddy 12in")
        pos.holdButton.tap()
        XCTAssertTrue(pos.heldBillsButton.waitForExistence(timeout: 5))
        pos.heldBillsButton.tap()
        XCTAssertTrue(app.navigationBars["Held bills"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Held'")).element(boundBy: 0).tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.tile(named: "Teddy 12in", onBill: 1).waitForExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.waitForNonExistence(timeout: 5))
    }

    // MARK: - Bill date

    func testBillDatePickerOpens() {
        pos.dateButton.tap()

        XCTAssertTrue(app.navigationBars["Bill date & time"].waitForExistence(timeout: 5))
    }

    // MARK: - Customer on bill survives cart changes

    func testCustomerStaysAttachedAfterAddingItem() {
        pos.openCustomerPicker()
        let picker = CustomerPickerScreen(app: app)
        picker.waitForScreen()
        let meena = picker.customer(named: "Meena S")
        XCTAssertTrue(meena.waitForExistence(timeout: 15), "Seeded customers did not load")
        meena.tap()
        pos.waitForScreen()
        pos.addItem(named: "Glass Bangles")

        XCTAssertTrue(pos.customerRow.label.contains("Meena S"))
    }

    // MARK: - Checkout

    func testCheckoutShowsTotalsAndPaymentModes() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()

        XCTAssertTrue(app.staticTexts["Walk-in customer"].exists)
        XCTAssertTrue(app.staticTexts["Payment"].exists)
        for mode in ["Cash", "UPI", "Card", "Credit"] {
            XCTAssertTrue(pos.paymentMode(mode).exists, "\(mode) chip missing")
        }
        XCTAssertTrue(pos.collectButton.isEnabled)
    }

    func testCreditWithWalkInCustomerIsBlocked() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Credit").tap()

        XCTAssertTrue(pos.creditNote.waitForExistence(timeout: 5))
        XCTAssertFalse(pos.collectButton.isEnabled)
        pos.paymentMode("Cash").tap()
        XCTAssertTrue(pos.collectButton.isEnabled, "Switching back to cash should unblock collect")
    }

    func testCashReceivedAboveTotalShowsChange() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        let cash = pos.cashReceivedField
        XCTAssertTrue(cash.waitForExistence(timeout: 5))
        cash.tap()
        cash.typeText("500")

        XCTAssertTrue(pos.changeDue.waitForExistence(timeout: 5))
    }

    func testCheckoutBackKeepsCart() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        app.buttons["BackButton"].tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.tile(named: "Glass Bangles", onBill: 1).exists)
    }

    func testCheckoutHoldBillReturnsToEmptyPOS() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.checkoutHoldButton.tap()

        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 10) || pos.customerRow.waitForExistence(timeout: 10))
    }

    func testSplitPaymentOpensKeypadScreen() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Split").tap()

        XCTAssertTrue(app.navigationBars["Split payment"].waitForExistence(timeout: 5))
        XCTAssertTrue(pos.splitPrimaryButton.exists)
    }

    func testCashSaleCompletesAndShowsReceipt() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.collectButton.tap()

        XCTAssertTrue(pos.receiptHome.waitForExistence(timeout: 15), "Receipt did not appear after collecting")
        XCTAssertTrue(pos.receiptNewBill.exists)
        XCTAssertFalse(app.buttons[AccessibilityID.Receipt.editBill].exists, "Edit bill is hidden right after checkout")
    }

    func testReceiptNewBillStartsFreshWalkInBill() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.collectButton.tap()
        XCTAssertTrue(pos.receiptNewBill.waitForExistence(timeout: 15))
        pos.receiptNewBill.tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.walkInLabel.exists)
        XCTAssertTrue(pos.emptyCartLabel.exists, "New bill after a sale must start empty")
    }

    func testReceiptBackToHomeShowsHome() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.collectButton.tap()
        XCTAssertTrue(pos.receiptHome.waitForExistence(timeout: 15))
        pos.receiptHome.tap()

        XCTAssertTrue(HomeScreen(app: app).newBillButton.waitForExistence(timeout: 10))
    }

    // MARK: - Checkout: payment modes

    func testCardSaleCompletesAndShowsReceipt() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Card").tap()
        pos.completeCashSale()
    }

    func testUPIOpensPayScreenAndMarkAsReceivedCompletesSale() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("UPI").tap()
        pos.collectButton.tap()

        XCTAssertTrue(app.navigationBars["Pay by UPI"].waitForExistence(timeout: 5), "UPI screen did not open")
        XCTAssertTrue(pos.upiMarkReceived.exists)
        pos.upiMarkReceived.tap()
        XCTAssertTrue(pos.receiptHome.waitForExistence(timeout: 15))
    }

    func testUPIChangeModeReturnsToCheckoutWithCartIntact() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("UPI").tap()
        pos.collectButton.tap()
        XCTAssertTrue(pos.upiChangeMode.waitForExistence(timeout: 5))
        pos.upiChangeMode.tap()

        XCTAssertTrue(app.navigationBars["Checkout"].waitForExistence(timeout: 5))
        XCTAssertTrue(pos.collectButton.exists)
    }

    func testBackFromUPIScreenDoesNotCompleteSale() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("UPI").tap()
        pos.collectButton.tap()
        XCTAssertTrue(app.navigationBars["Pay by UPI"].waitForExistence(timeout: 5))
        app.buttons["BackButton"].tap()

        XCTAssertTrue(app.navigationBars["Checkout"].waitForExistence(timeout: 5))
        XCTAssertFalse(pos.receiptHome.exists)
    }

    func testSwitchingModesKeepsCollectEnabled() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        for mode in ["Card", "UPI", "Cash"] {
            pos.paymentMode(mode).tap()
            XCTAssertTrue(pos.collectButton.isEnabled, "Collect disabled on \(mode)")
        }
    }

    // MARK: - Checkout: credit

    func testCreditSaleWithAttachedCustomerCompletes() {
        attachCustomer(named: "Meena S")
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Credit").tap()

        XCTAssertFalse(pos.creditNote.exists, "Credit note should not show once a customer is attached")
        XCTAssertTrue(pos.collectButton.isEnabled)
        pos.completeCashSale()
    }

    func testCheckoutShowsAttachedCustomerName() {
        attachCustomer(named: "Ravi Kumar")
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()

        XCTAssertTrue(pos.checkoutCustomerRow.label.contains("Ravi Kumar"), "Checkout row: \(pos.checkoutCustomerRow.label)")
        XCTAssertFalse(app.staticTexts["Walk-in customer"].exists)
    }

    func testChangingCustomerFromCheckoutUnblocksCredit() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Credit").tap()
        XCTAssertFalse(pos.collectButton.isEnabled)
        pos.checkoutCustomerRow.tap()
        let picker = CustomerPickerScreen(app: app)
        picker.waitForScreen()
        let sneha = picker.customer(named: "Sneha P")
        XCTAssertTrue(sneha.waitForExistence(timeout: 15), "Seeded customers did not load")
        sneha.tap()

        XCTAssertTrue(app.navigationBars["Checkout"].waitForExistence(timeout: 5))
        XCTAssertTrue(pos.checkoutCustomerRow.label.contains("Sneha P"))
        XCTAssertTrue(pos.collectButton.isEnabled, "Credit should be allowed with a customer")
    }

    // MARK: - Checkout: totals and cash

    func testBillDiscountReducesCollectAmount() {
        pos.addItem(named: "Glass Bangles")
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

    func testTwoItemsIncreaseCollectAmount() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        let single = pos.collectButton.label
        app.buttons["BackButton"].tap()
        pos.waitForScreen()
        pos.addItem(named: "Key Chain")
        pos.openCheckout()

        XCTAssertNotEqual(pos.collectButton.label, single)
    }

    func testCashReceivedBelowTotalShowsNoChange() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.cashReceivedField.tap()
        pos.cashReceivedField.typeText("10")

        XCTAssertFalse(pos.changeDue.exists)
        XCTAssertTrue(pos.collectButton.isEnabled, "Cash received is optional and informational")
    }

    func testCashSaleWithCashReceivedCompletes() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.cashReceivedField.tap()
        pos.cashReceivedField.typeText("500")
        XCTAssertTrue(pos.changeDue.waitForExistence(timeout: 5))
        app.keyboards.buttons["Return"].tapIfExists()
        pos.completeCashSale()
    }

    // MARK: - Checkout: split

    func testSplitCashPlusUPICompletesSale() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Split").tap()
        XCTAssertTrue(app.navigationBars["Split payment"].waitForExistence(timeout: 5))
        pos.key("5").tap()
        pos.key("0").tap()
        pos.splitPrimaryButton.tap()
        pos.splitSegment("UPI").tap()
        pos.splitPrimaryButton.tap()

        XCTAssertTrue(pos.splitPrimaryButton.label.hasPrefix("Confirm"), "Primary should become Confirm once settled: \(pos.splitPrimaryButton.label)")
        pos.splitPrimaryButton.tap()
        XCTAssertTrue(pos.receiptHome.waitForExistence(timeout: 15))
    }

    func testSplitFullAmountInOneModeSettlesImmediately() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Split").tap()
        XCTAssertTrue(pos.splitPrimaryButton.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.splitPrimaryButton.label.hasPrefix("Add"))
        pos.splitPrimaryButton.tap()

        XCTAssertTrue(pos.splitPrimaryButton.label.hasPrefix("Confirm"))
    }

    func testSplitPartialLeavesRemainingAndAddButton() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Split").tap()
        XCTAssertTrue(app.navigationBars["Split payment"].waitForExistence(timeout: 5))
        pos.key("1").tap()
        pos.key("0").tap()
        pos.splitPrimaryButton.tap()

        XCTAssertTrue(pos.splitPrimaryButton.label.hasPrefix("Add"), "Remaining balance should keep the Add button")
        XCTAssertTrue(app.staticTexts["Pending"].exists)
    }

    func testSplitCreditWithoutCustomerShowsWarning() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Split").tap()
        XCTAssertTrue(app.navigationBars["Split payment"].waitForExistence(timeout: 5))
        pos.splitSegment("Credit").tap()
        pos.splitPrimaryButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.SplitPayment.creditNote].waitForExistence(timeout: 5)
                      || app.descendants(matching: .any)[AccessibilityID.SplitPayment.error].exists)
    }

    func testBackFromSplitKeepsCart() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.paymentMode("Split").tap()
        XCTAssertTrue(app.navigationBars["Split payment"].waitForExistence(timeout: 5))
        app.buttons["BackButton"].tap()
        app.buttons["BackButton"].tap()

        pos.waitForScreen()
        XCTAssertTrue(pos.tile(named: "Glass Bangles", onBill: 1).exists)
    }

    // MARK: - After the sale

    func testSaleClearsCartSoNextBillIsEmptyAndNotCheckoutable() {
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.completeCashSale()
        pos.receiptNewBill.tap()
        pos.waitForScreen()

        XCTAssertFalse(pos.checkoutButton.isEnabled)
        XCTAssertFalse(pos.tile(named: "Glass Bangles", onBill: 1).exists)
    }

    func testCustomerFromCompletedSaleDoesNotLeakIntoNextBill() {
        attachCustomer(named: "Ravi Kumar")
        pos.addItem(named: "Glass Bangles")
        pos.openCheckout()
        pos.completeCashSale()
        pos.receiptNewBill.tap()
        pos.waitForScreen()

        XCTAssertTrue(pos.walkInLabel.waitForExistence(timeout: 5), "Next bill should start as walk-in")
    }

    // MARK: - Close / unsaved bill

    func testCloseWithEmptyCartLeavesImmediately() {
        app.buttons["Close"].tap()

        XCTAssertTrue(HomeScreen(app: app).newBillButton.waitForExistence(timeout: 10))
    }

    func testCloseWithItemsAsksBeforeLeaving() {
        pos.addItem(named: "Glass Bangles")
        app.buttons["Close"].tap()

        XCTAssertTrue(app.buttons["Discard bill"].waitForExistence(timeout: 5), "Unsaved-bill dialog did not appear")
        XCTAssertTrue(app.buttons["Keep billing"].exists)
        XCTAssertTrue(app.sheets.firstMatch.buttons["Hold bill"].exists)
    }

    func testKeepBillingStaysOnPOSWithCartIntact() {
        pos.addItem(named: "Glass Bangles")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Keep billing"].waitForExistence(timeout: 5))
        app.buttons["Keep billing"].tap()

        XCTAssertTrue(app.buttons["Keep billing"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.tile(named: "Glass Bangles", onBill: 1).exists)
    }

    func testDiscardBillLeavesAndNextBillIsEmpty() {
        pos.addItem(named: "Glass Bangles")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Discard bill"].waitForExistence(timeout: 5))
        app.buttons["Discard bill"].tap()

        let home = HomeScreen(app: app)
        XCTAssertTrue(home.newBillButton.waitForExistence(timeout: 10))
        home.openNewBill()
        pos.waitForScreen()
        XCTAssertTrue(pos.emptyCartLabel.exists, "Discarded cart must not come back")
        XCTAssertTrue(app.buttons["Held bills (0)"].exists, "Discard must not park the bill")
    }

    func testHoldFromCloseDialogParksBillAndLeaves() {
        pos.addItem(named: "Glass Bangles")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.sheets.firstMatch.buttons["Hold bill"].waitForExistence(timeout: 5))
        app.sheets.firstMatch.buttons["Hold bill"].tap()

        let home = HomeScreen(app: app)
        XCTAssertTrue(home.newBillButton.waitForExistence(timeout: 10))
        home.openNewBill()
        pos.waitForScreen()
        XCTAssertTrue(pos.emptyCartLabel.exists)
        XCTAssertTrue(pos.heldBillsButton.label.contains("(1)"), "Held count: \(pos.heldBillsButton.label)")
    }

    // MARK: - Bill discount: modes, rounding, PIN

    func testRoundToChipAppliesDiscountToNearestFifty() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Bill discount")
        let round = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Round to'")).firstMatch
        XCTAssertTrue(round.waitForExistence(timeout: 5), "Rs 120 should offer a round-down chip")
        round.tap()
        pos.applyDiscountButton.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Discount'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testAmountModeDiscountApplies() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.buttons["₹ amount"].waitForExistence(timeout: 5))
        app.buttons["₹ amount"].tap()
        pos.key("5").tap()
        pos.applyDiscountButton.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Discount'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testWrongManagerPinShowsErrorAndKeepsApplyDisabled() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.buttons["%"].waitForExistence(timeout: 5))
        app.buttons["%"].tap()
        pos.key("9").tap()
        pos.key("0").tap()
        XCTAssertTrue(app.staticTexts["Manager PIN"].waitForExistence(timeout: 5))
        for _ in 0..<4 { pos.key("1").tap() }

        XCTAssertTrue(app.staticTexts["That PIN isn't a manager's. Try again."].waitForExistence(timeout: 5))
        XCTAssertFalse(pos.applyDiscountButton.isEnabled)
    }

    func testLoweringDiscountBelowLimitHidesManagerPin() {
        pos.addItem(named: "Glass Bangles")
        pos.openMenu("Bill discount")
        XCTAssertTrue(app.buttons["%"].waitForExistence(timeout: 5))
        app.buttons["%"].tap()
        pos.key("9").tap()
        pos.key("0").tap()
        XCTAssertTrue(app.staticTexts["Manager PIN"].waitForExistence(timeout: 5))
        pos.discountPreset(5).tap()

        XCTAssertTrue(app.staticTexts["Manager PIN"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.applyDiscountButton.isEnabled)
    }

    // MARK: - Helpers

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
