//
//  CustomerListUITests.swift
//  ApoorvaUITests
//
//  Runs against the seeded sample shop (`AppLauncher.launchSeeded`): Ravi Kumar, Meena S (₹1,120 due),
//  Sneha P, Anil Regular (6 visits) and Kavya New (created today, no visits).
//
//  The whole screen is one test so the app launches and seeds once. Scenarios run in order; the ones that
//  change the seeded data (they can't be undone in-app) come last.
//

import XCTest

@MainActor
final class CustomerListUITests: XCTestCase {
    private var app: XCUIApplication!
    private var list: CustomerListScreen!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppLauncher.launchSeeded()
        HomeScreen(app: app).waitForSeededHome()
        list = CustomerListScreen(app: app)
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testCustomerList() {
        scenario("Summary and rows") { summaryAndRows() }
        scenario("Search") { search() }
        scenario("Filters") { filters() }
        scenario("Row actions") { rowActions() }
        scenario("More menu") { moreMenu() }
        scenario("Add customer form") { addCustomerForm() }
        scenario("Add customer") { addCustomer() }
        scenario("Mask phone numbers") { maskPhoneNumbers() }
    }

    // MARK: - Scenarios

    private func summaryAndRows() {
        XCTAssertTrue(list.summary("5 customers").waitForExistence(timeout: 5))
        XCTAssertTrue(list.summary("₹1,120 due").exists)

        for name in ["Ravi Kumar", "Meena S", "Sneha P", "Anil Regular", "Kavya New"] {
            XCTAssertTrue(list.row(named: name).waitForExistence(timeout: 5), "\(name) missing")
        }

        XCTAssertTrue(rowExists("label CONTAINS '9848012345' AND label CONTAINS '4 visits'"), "phone and visit count")
        XCTAssertTrue(rowExists("label BEGINSWITH 'Meena S, ' AND label CONTAINS '₹1,120 due'"), "due badge")
        XCTAssertTrue(rowExists("label BEGINSWITH 'Anil Regular, ' AND label CONTAINS 'Regular'"), "regular badge")
        XCTAssertTrue(rowExists("label BEGINSWITH 'Kavya New, ' AND label CONTAINS 'no visits yet'"), "no visits yet")
    }

    private func search() {
        list.search("Meena")
        XCTAssertTrue(list.row(named: "Meena S").waitForExistence(timeout: 5))
        XCTAssertFalse(list.row(named: "Ravi Kumar").exists)

        clearSearch(count: 5)
        XCTAssertTrue(list.row(named: "Ravi Kumar").waitForExistence(timeout: 5), "clearing search restores the list")

        list.search("9988776655")
        XCTAssertTrue(list.row(named: "Sneha P").waitForExistence(timeout: 5))
        XCTAssertFalse(list.row(named: "Meena S").exists)

        clearSearch(count: 10)
        list.search("Zzzz")
        XCTAssertTrue(list.noMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(list.row(named: "Ravi Kumar").exists)

        clearSearch(count: 4)
        XCTAssertTrue(list.row(named: "Ravi Kumar").waitForExistence(timeout: 5))
    }

    private func filters() {
        list.select(filter: "With dues")
        XCTAssertTrue(list.row(named: "Meena S").waitForExistence(timeout: 5))
        XCTAssertFalse(list.row(named: "Ravi Kumar").exists)
        XCTAssertFalse(list.row(named: "Anil Regular").exists)

        list.search("Ravi")
        XCTAssertTrue(list.noMatch.waitForExistence(timeout: 5), "filter and search combine")
        clearSearch(count: 4)

        list.select(filter: "Regulars")
        XCTAssertTrue(list.row(named: "Anil Regular").waitForExistence(timeout: 5))
        XCTAssertFalse(list.row(named: "Meena S").exists)

        list.select(filter: "New this month")
        XCTAssertTrue(list.row(named: "Kavya New").waitForExistence(timeout: 5))
        XCTAssertFalse(list.row(named: "Ravi Kumar").exists)

        list.select(filter: "All")
        XCTAssertTrue(list.row(named: "Ravi Kumar").waitForExistence(timeout: 5), "All restores every customer")
        XCTAssertTrue(list.row(named: "Kavya New").exists)

        list.summary("₹1,120 due").tap()
        XCTAssertTrue(list.row(named: "Meena S").waitForExistence(timeout: 5), "dues summary filters to customers who owe")
        XCTAssertFalse(list.row(named: "Ravi Kumar").exists)
        list.select(filter: "All")
    }

    private func rowActions() {
        list.row(named: "Meena S").tap()
        XCTAssertTrue(app.navigationBars["Meena S"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Balance due"].exists)
        XCTAssertTrue(app.buttons["Collect due"].exists)
        app.buttons["BackButton"].tap()
        list.waitForScreen()

        list.row(named: "Ravi Kumar").tap()
        XCTAssertTrue(app.navigationBars["Ravi Kumar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Collect due"].exists)
        XCTAssertTrue(app.buttons["New bill"].exists)
        app.buttons["BackButton"].tap()
        list.waitForScreen()

        list.row(named: "Meena S").press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Call"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["WhatsApp"].exists)
        XCTAssertTrue(app.buttons["Copy number"].exists)
    }

    private func moreMenu() {
        list.moreMenu.tap()
        XCTAssertTrue(app.buttons["Export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sync now"].exists)
        XCTAssertTrue(app.buttons["Show last 4 digits"].exists)
    }

    private func addCustomerForm() {
        list.addButton.tap()
        XCTAssertTrue(app.navigationBars["New customer"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save customer"].isEnabled, "save is disabled until the form is filled")
        app.buttons["BackButton"].tap()
        list.waitForScreen()
    }

    private func addCustomer() {
        list.addButton.tap()
        let name = app.textFields["Anitha Rao"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Zoya Test")
        let phone = app.textFields["+91 97010 55443"]
        phone.tap()
        phone.typeText("9811122233")
        let save = app.buttons["Save customer"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        // Saving a new customer opens their detail screen; go back to the list.
        XCTAssertTrue(app.navigationBars["Zoya Test"].waitForExistence(timeout: 10))
        app.buttons["BackButton"].tap()
        list.waitForScreen()
        XCTAssertTrue(list.row(named: "Zoya Test").waitForExistence(timeout: 10))
        XCTAssertTrue(list.summary("6 customers").exists)
    }

    private func maskPhoneNumbers() {
        // The toggle is an @AppStorage preference; the next launch starts from full numbers again.
        list.moreMenu.tap()
        app.buttons["Show last 4 digits"].tap()
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS '9848012345'")).firstMatch.waitForExistence(timeout: 3))
        list.moreMenu.tap()
        XCTAssertTrue(app.buttons["Show full numbers"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func scenario(_ name: String, _ body: () -> Void) {
        XCTContext.runActivity(named: name) { _ in
            resetToCustomersList()
            body()
        }
    }

    private func rowExists(_ predicate: String) -> Bool {
        app.buttons.matching(NSPredicate(format: predicate)).firstMatch.exists
    }

    private func clearSearch(count: Int) {
        list.searchField.tap()
        list.searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
    }

    /// Returns the app to a known state: no pushed screens, sheets or menus, empty search, "All" filter.
    private func resetToCustomersList() {
        dismissOverlays()
        let home = HomeScreen(app: app)
        let homeTab = app.tabBars.buttons["Home"]
        if homeTab.waitForExistence(timeout: 10) { homeTab.tap() }
        home.openCustomersTab()
        // Tapping the selected tab pops a pushed detail/form back to the list.
        app.tabBars.buttons["Customers"].tap()
        list.waitForScreen()
        if let text = list.searchField.value as? String, !text.isEmpty, text != "Name or phone" {
            clearSearch(count: text.count)
        }
        list.select(filter: "All")
    }

    private func dismissOverlays() {
        for _ in 0..<3 {
            if app.keyboards.count > 0, app.buttons["Return"].exists { app.buttons["Return"].tap() }
            if app.sheets.count > 0 || app.otherElements["PopoverDismissRegion"].exists {
                app.otherElements["PopoverDismissRegion"].firstMatch.tap()
            }
            let back = app.buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
    }
}
