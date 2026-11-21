//
//  KiranaPOSUITests.swift
//  ApoorvaUITests
//
//  Weighed items ("Onions (kg)", sold per kg) and variant items ("Tea Powder 250g", sizes 100g/250g/500g,
//  seeded by DemoSeeder) only exist in the kirana sample shop, so these run against it instead of the fancy one.
//  Prices: Onions Rs 35/kg, Tea Powder Rs 120, Toor Dal Rs 160.
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
        app = AppLauncher.launch()
        let home = HomeScreen(app: app)
        home.enterDemoShop(sampleShop: "Sri Lakshmi Stores")
        home.openNewBill()
        pos = POSScreen(app: app)
        pos.waitForScreen()
        XCTAssertTrue(pos.item(named: onions).waitForExistence(timeout: 15), "Kirana quick items did not load")
    }

    // MARK: - Weighed item

    func testTappingLooseItemOpensWeightSheet() {
        pos.item(named: onions).tap()

        XCTAssertTrue(app.navigationBars[onions].waitForExistence(timeout: 5), "Weight sheet did not open")
        XCTAssertTrue(app.buttons["By weight"].exists)
        XCTAssertTrue(app.buttons["By amount"].exists)
        XCTAssertTrue(addWeightButton.exists)
    }

    func testWeightSheetDefaultsToHalfKgAtShelfPrice() {
        pos.item(named: onions).tap()

        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addWeightButton.label.contains("₹18"), "0.5 kg at Rs 35 should be Rs 18: \(addWeightButton.label)")
    }

    func testWeightPresetsUpdateAmount() {
        pos.item(named: onions).tap()
        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5))

        app.buttons["1 kg"].tap()
        XCTAssertTrue(addWeightButton.label.contains("₹35"), "1 kg: \(addWeightButton.label)")
        app.buttons["2 kg"].tap()
        XCTAssertTrue(addWeightButton.label.contains("₹70"), "2 kg: \(addWeightButton.label)")
        app.buttons["250 g"].tap()
        XCTAssertTrue(addWeightButton.label.contains("₹9"), "250 g: \(addWeightButton.label)")
    }

    func testAddingWeighedItemPutsLineInCart() {
        addOnions(preset: "1 kg")

        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.checkoutButton.isEnabled)
        XCTAssertEqual(pos.cartLines().count, 1)
    }

    func testWeighedLineShowsPerKgPrice() {
        addOnions(preset: "1 kg")

        let perKg = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/kg'")).firstMatch
        XCTAssertTrue(perKg.waitForExistence(timeout: 5), "Cart line should show the per-kg price")
    }

    func testDismissingWeightSheetWithoutAddingKeepsCartEmpty() {
        pos.item(named: onions).tap()
        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5))
        app.swipeDown()

        XCTAssertTrue(addWeightButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.exists)
        XCTAssertFalse(pos.checkoutButton.isEnabled)
    }

    func testByAmountModeHidesWeightPresets() {
        pos.item(named: onions).tap()
        XCTAssertTrue(app.buttons["1 kg"].waitForExistence(timeout: 5))
        app.buttons["By amount"].tap()

        XCTAssertTrue(app.buttons["1 kg"].waitForNonExistence(timeout: 5), "Presets are weight-only")
        XCTAssertTrue(addWeightButton.exists)
        app.buttons["By weight"].tap()
        XCTAssertTrue(app.buttons["1 kg"].waitForExistence(timeout: 5))
    }

    func testTappingLooseItemTwiceReopensWeightSheet() {
        addOnions(preset: "1 kg")
        pos.item(named: onions).tap()

        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5), "Loose items always ask for a weight")
    }

    func testEditingWeighedLineHasNoQuantityStepper() {
        addOnions(preset: "1 kg")
        pos.cartLines().firstMatch.tap()

        XCTAssertTrue(pos.removeLineButton.waitForExistence(timeout: 5), "Edit sheet did not open from the cart line")
        XCTAssertFalse(pos.increaseQuantity.exists, "Weighed lines are edited by weight, not quantity")
    }

    func testRemovingWeighedLineEmptiesCart() {
        addOnions(preset: "1 kg")
        pos.cartLines().firstMatch.tap()
        XCTAssertTrue(pos.removeLineButton.waitForExistence(timeout: 5))
        pos.removeLineButton.tap()

        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
    }

    func testWeighedItemSaleCompletesToReceipt() {
        addOnions(preset: "2 kg")
        pos.openCheckout()
        pos.completeCashSale()
    }

    // MARK: - Variant item

    func testTappingVariantItemOpensVariantSheet() {
        pos.item(named: tea).tap()

        XCTAssertTrue(app.navigationBars[tea].waitForExistence(timeout: 5), "Variant sheet did not open")
        XCTAssertTrue(app.staticTexts["Size"].exists)
        for size in ["100g", "250g", "500g"] {
            XCTAssertTrue(app.buttons[size].exists, "\(size) option missing")
        }
        XCTAssertTrue(addVariantButton.exists)
    }

    func testVariantSheetHasNoColourSectionWhenNoColours() {
        pos.item(named: tea).tap()
        XCTAssertTrue(addVariantButton.waitForExistence(timeout: 5))

        XCTAssertFalse(app.staticTexts["Colour"].exists)
    }

    func testVariantSheetDefaultsToQuantityOneAtShelfPrice() {
        pos.item(named: tea).tap()

        XCTAssertTrue(addVariantButton.waitForExistence(timeout: 5))
        XCTAssertEqual(variantQuantity.value as? String, "1")
        XCTAssertTrue(addVariantButton.label.contains("₹120"), addVariantButton.label)
    }

    func testVariantQuantityUpdatesAddButtonTotal() {
        pos.item(named: tea).tap()
        setVariantQuantity("3")

        XCTAssertTrue(addVariantButton.label.contains("₹360"), "3 x Rs 120: \(addVariantButton.label)")
    }

    func testBlankVariantQuantityClampsToOne() {
        pos.item(named: tea).tap()
        setVariantQuantity("")

        XCTAssertTrue(addVariantButton.label.contains("₹120"), "Blank quantity should bill as 1: \(addVariantButton.label)")
    }

    func testZeroVariantQuantityClampsToOne() {
        pos.item(named: tea).tap()
        setVariantQuantity("0")

        XCTAssertTrue(addVariantButton.label.contains("₹120"), "Zero quantity should bill as 1: \(addVariantButton.label)")
    }

    func testAddingVariantItemPutsLineInCart() {
        pos.item(named: tea).tap()
        XCTAssertTrue(addVariantButton.waitForExistence(timeout: 5))
        addVariantButton.tap()

        XCTAssertTrue(addVariantButton.waitForNonExistence(timeout: 5), "Variant sheet did not close")
        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(pos.checkoutButton.isEnabled)
    }

    func testChosenSizeAppearsOnCartLine() {
        pos.item(named: tea).tap()
        XCTAssertTrue(app.buttons["500g"].waitForExistence(timeout: 5))
        app.buttons["500g"].tap()
        addVariantButton.tap()

        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        let line = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '500g'")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Chosen size should show on the cart line")
    }

    func testDismissingVariantSheetWithoutAddingKeepsCartEmpty() {
        pos.item(named: tea).tap()
        XCTAssertTrue(addVariantButton.waitForExistence(timeout: 5))
        app.swipeDown()

        XCTAssertTrue(addVariantButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(pos.emptyCartLabel.exists)
    }

    func testVariantItemSaleCompletesToReceipt() {
        pos.item(named: tea).tap()
        setVariantQuantity("2")
        addVariantButton.tap()
        XCTAssertTrue(pos.currentCartHeader.waitForExistence(timeout: 5))
        pos.openCheckout()
        pos.completeCashSale()
    }

    // MARK: - Mixed carts

    func testPlainItemInKiranaStillUsesQuickAddSheet() {
        pos.item(named: "Toor Dal 1kg").tap()

        XCTAssertTrue(pos.addToBillButton.waitForExistence(timeout: 5), "Plain items keep the MRP/quantity sheet")
        XCTAssertFalse(addWeightButton.exists)
        XCTAssertFalse(addVariantButton.exists)
    }

    func testMixedCartOfWeighedVariantAndPlainItemsCountsThreeItems() {
        addOnions(preset: "1 kg")
        pos.item(named: tea).tap()
        XCTAssertTrue(addVariantButton.waitForExistence(timeout: 5))
        addVariantButton.tap()
        XCTAssertTrue(addVariantButton.waitForNonExistence(timeout: 5))
        pos.addItem(named: "Toor Dal 1kg")

        XCTAssertTrue(app.staticTexts["3 items"].waitForExistence(timeout: 5))
        pos.openCheckout()
        pos.completeCashSale()
    }

    func testClearBillRemovesWeighedAndVariantLines() {
        addOnions(preset: "1 kg")
        pos.item(named: tea).tap()
        XCTAssertTrue(addVariantButton.waitForExistence(timeout: 5))
        addVariantButton.tap()
        XCTAssertTrue(addVariantButton.waitForNonExistence(timeout: 5))
        pos.openMenu("Clear bill")

        XCTAssertTrue(pos.emptyCartLabel.waitForExistence(timeout: 5))
        XCTAssertFalse(pos.checkoutButton.isEnabled)
    }

    // MARK: - Helpers

    private var addWeightButton: XCUIElement { app.buttons[AccessibilityID.WeightSheet.add] }
    private var addVariantButton: XCUIElement { app.buttons[AccessibilityID.VariantSheet.add] }
    private var variantQuantity: XCUIElement { app.textFields[AccessibilityID.VariantSheet.quantity] }

    private func addOnions(preset: String) {
        pos.item(named: onions).tap()
        XCTAssertTrue(addWeightButton.waitForExistence(timeout: 5), "Weight sheet did not open")
        app.buttons[preset].tap()
        addWeightButton.tap()
        XCTAssertTrue(addWeightButton.waitForNonExistence(timeout: 5), "Weight sheet did not close")
    }

    /// Replaces the variant sheet's quantity text (it starts at "1").
    private func setVariantQuantity(_ text: String) {
        XCTAssertTrue(variantQuantity.waitForExistence(timeout: 5))
        variantQuantity.tap()
        variantQuantity.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        if !text.isEmpty { variantQuantity.typeText(text) }
    }
}
