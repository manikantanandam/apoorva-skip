//
//  KiranaPOSUITests.swift
//  ApoorvaUITests
//
//  Weighed items ("Onions (kg)", sold per kg) and variant items ("Tea Powder 250g", sizes 100g/250g/500g,
//  seeded by DemoSeeder) only exist in the kirana sample shop, so these run against it instead of the fancy one.
//  Prices: Onions Rs 35/kg, Tea Powder Rs 120, Toor Dal Rs 160.
//
//  The whole screen is one test so the app launches and seeds once. Each scenario starts from an empty bill;
//  the scenarios that finish a sale (and so leave the POS screen) come last.
//

import XCTest

@MainActor
final class KiranaPOSUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pos: POSScreen!

    private let onions = "Onions (kg)"
    private let tea = "Tea Powder 250g"

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launchSeeded(vertical: "kirana")
        let home = HomeScreen(app: app)
        home.waitForSeededHome()
        home.openNewBill()
        pos = POSScreen(app: app)
        pos.waitForScreen()
        XCTAssertTrue(pos.item(named: onions).waitForExistence(timeout: 15), "Kirana quick items did not load")
    }

    func testKiranaPOS() {
        scenario("Weight sheet") { weightSheet() }
        scenario("Weighed line in cart") { weighedLineInCart() }
        scenario("Variant sheet") { variantSheet() }
        scenario("Variant line in cart") { variantLineInCart() }
        scenario("Plain item quick add") { plainItemQuickAdd() }
        scenario("Clear bill") { clearBill() }
        scenario("Weighed item sale") { weighedItemSale() }
        scenario("Variant item sale") { variantItemSale() }
        scenario("Mixed cart sale") { mixedCartSale() }
    }

    // MARK: - Scenarios

    private func weightSheet() {
        pos.item(named: onions).tap()
        XCTAssertTrue(app.navigationBars[onions].waitForExistence(timeout: 5), "Weight sheet did not open")
        XCTAssertTrue(app.buttons["By weight"].exists)
        XCTAssertTrue(app.buttons["By amount"].exists)
        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addWeightButton.label.contains("₹18"), "0.5 kg at Rs 35 should be Rs 18: \(addWeightButton.label)")

        dismissSheet()
        XCTAssertTrue(addWeightButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.exists, "Dismissing the sheet keeps the cart empty")
        XCTAssertFalse(pos.checkoutButton.isEnabled)

        pos.item(named: onions).tap()
        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5))
        app.buttons["1 kg"].tap()
        XCTAssertTrue(addWeightButton.label.contains("₹35"), "1 kg: \(addWeightButton.label)")
        app.buttons["2 kg"].tap()
        XCTAssertTrue(addWeightButton.label.contains("₹70"), "2 kg: \(addWeightButton.label)")
        app.buttons["250 g"].tap()
        XCTAssertTrue(addWeightButton.label.contains("₹9"), "250 g: \(addWeightButton.label)")

        app.buttons["By amount"].tap()
        XCTAssertTrue(app.buttons["1 kg"].waitForNonExistence(timeout: 5), "Presets are weight-only")
        XCTAssertTrue(addWeightButton.exists)
        app.buttons["By weight"].tap()
        XCTAssertTrue(app.buttons["1 kg"].waitForExistence(timeout: 5))
    }

    private func weighedLineInCart() {
        addOnions(preset: "1 kg")
        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.checkoutButton.isEnabled)
        XCTAssertEqual(pos.cartLines().count, 1)

        let perKg = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/kg'")).firstMatch
        XCTAssertTrue(perKg.waitForExistence(timeout: 5), "Cart line should show the per-kg price")

        // TODO: tapping the cart line shows no edit sheet on device (the old edit/remove-line test is not covered here).
        pos.item(named: onions).tap()
        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5), "Loose items always ask for a weight")
    }

    private func variantSheet() {
        pos.item(named: tea).tap()
        XCTAssertTrue(app.navigationBars[tea].waitForExistence(timeout: 5), "Variant sheet did not open")
        XCTAssertTrue(app.staticTexts["Size"].exists)
        for size in ["100g", "250g", "500g"] {
            XCTAssertTrue(app.buttons[size].exists, "\(size) option missing")
        }
        XCTAssertTrue(addVariantButton.exists)
        XCTAssertFalse(app.staticTexts["Colour"].exists, "No colour section when the item has no colours")

        XCTAssertEqual(variantQuantity.value as? String, "1")
        XCTAssertTrue(addVariantButton.label.contains("₹120"), addVariantButton.label)

        setVariantQuantity("3")
        XCTAssertTrue(addVariantButton.label.contains("₹360"), "3 x Rs 120: \(addVariantButton.label)")
        setVariantQuantity("")
        XCTAssertTrue(addVariantButton.label.contains("₹120"), "Blank quantity should bill as 1: \(addVariantButton.label)")
        setVariantQuantity("0")
        XCTAssertTrue(addVariantButton.label.contains("₹120"), "Zero quantity should bill as 1: \(addVariantButton.label)")

        dismissSheet()
        XCTAssertTrue(addVariantButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.exists, "Dismissing the sheet keeps the cart empty")
    }

    private func variantLineInCart() {
        pos.item(named: tea).tap()
        XCTAssertTrue(app.buttons["500g"].waitForExistence(timeout: 5))
        app.buttons["500g"].tap()
        addVariantButton.tap()

        XCTAssertTrue(addVariantButton.waitForNonExistence(timeout: 5), "Variant sheet did not close")
        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.checkoutButton.isEnabled)
        let line = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '500g'")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Chosen size should show on the cart line")
    }

    private func plainItemQuickAdd() {
        pos.item(named: "Toor Dal 1kg").tap()
        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5), "Plain items keep the MRP/quantity sheet")
        XCTAssertFalse(addWeightButton.exists)
        XCTAssertFalse(addVariantButton.exists)
    }

    private func clearBill() {
        addOnions(preset: "1 kg")
        addTea()
        pos.openMenu("Clear bill")

        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertFalse(pos.checkoutButton.isEnabled)
    }

    private func weighedItemSale() {
        addOnions(preset: "2 kg")
        pos.openCheckout()
        pos.completeCashSale()
    }

    private func variantItemSale() {
        pos.item(named: tea).tap()
        setVariantQuantity("2")
        addVariantButton.tap()
        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        pos.openCheckout()
        pos.completeCashSale()
    }

    private func mixedCartSale() {
        addOnions(preset: "1 kg")
        addTea()
        pos.addItem(named: "Toor Dal 1kg")

        XCTAssertTrue(app.staticTexts["3 items"].waitForExistence(timeout: 5))
        pos.openCheckout()
        pos.completeCashSale()
    }

    // MARK: - Helpers

    private var addWeightButton: XCUIElement { app.buttons[AccessibilityID.WeightSheet.add] }
    private var addVariantButton: XCUIElement { app.buttons[AccessibilityID.VariantSheet.add] }
    private var variantQuantity: XCUIElement { app.textFields[AccessibilityID.VariantSheet.quantity] }

    private func scenario(_ name: String, _ body: () -> Void) {
        XCTContext.runActivity(named: name) { _ in
            resetToEmptyBill()
            body()
        }
    }

    /// Back to the POS screen with no open sheet and an empty cart (starts a new bill after a receipt).
    private func resetToEmptyBill() {
        if pos.receiptNewBill.exists { pos.receiptNewBill.tap() }
        if addWeightButton.exists || addVariantButton.exists || pos.addToBillButton.exists { dismissSheet() }
        pos.waitForScreen()
        if pos.checkoutButton.isEnabled { pos.openMenu("Clear bill") }
        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5), "Bill did not reset to empty")
    }

    /// Closes the open sheet with its Close button. The sheets are full height, so a swipe doesn't dismiss them
    /// reliably; the sheet's Close is the last full-size one (other Close buttons are on the screen underneath or tiny banners).
    private func dismissSheet() {
        let closeButtons = app.buttons.matching(NSPredicate(format: "label == 'Close'")).allElementsBoundByIndex
        closeButtons.last(where: { $0.frame.width > 30 })?.tap()
    }

    private func addOnions(preset: String) {
        pos.item(named: onions).tap()
        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5), "Weight sheet did not open")
        app.buttons[preset].tap()
        addWeightButton.tap()
        XCTAssertTrue(addWeightButton.waitForNonExistence(timeout: 5), "Weight sheet did not close")
    }

    private func addTea() {
        pos.item(named: tea).tap()
        XCTAssertTrue(addVariantButton.waitForExistence(timeout: 5))
        addVariantButton.tap()
        XCTAssertTrue(addVariantButton.waitForNonExistence(timeout: 5))
    }

    /// Replaces the variant sheet's quantity text (it starts at "1").
    private func setVariantQuantity(_ text: String) {
        XCTAssertTrue(variantQuantity.waitForExistence(timeout: 5))
        variantQuantity.tap()
        variantQuantity.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        if !text.isEmpty { variantQuantity.typeText(text) }
    }
}
