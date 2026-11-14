//
//  CoverageGapTests.swift
//  ApoorvaModels
//
//  Remaining branches: every enum title, both sort directions, tenure variants and raw-string decoding.
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Coverage Gap Tests")
struct CoverageGapTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - Enum titles and raw values

    @Test("Every attendance status has its title")
    func attendanceTitles() {
        #expect(AttendanceStatus.present.title == "Present")
        #expect(AttendanceStatus.half.title == "Half day")
        #expect(AttendanceStatus.absent.title == "Absent")
        #expect(AttendanceStatus.leave.title == "Leave")
    }

    @Test("Enums decode from raw strings and reject unknown ones")
    func enumDecoding() throws {
        #expect(try decode(SalaryPaymentKind.self, "\"salary\"") == .salary)
        #expect(try decode(SalaryPaymentKind.self, "\"advance\"") == .advance)
        #expect(try decode(SupplierLedgerKind.self, "\"purchaseReturn\"") == .purchaseReturn)
        #expect(try decode(ExpenseCategory.self, "\"tea\"") == .tea)
        #expect(try decode(AttendanceStatus.self, "\"half\"") == .half)
        #expect(throws: (any Error).self) { _ = try decode(SalaryPaymentKind.self, "\"bonus\"") }
        #expect(throws: (any Error).self) { _ = try decode(ExpenseCategory.self, "\"party\"") }
    }

    @Test("Records round-trip through Codable")
    func recordsRoundTrip() throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let expense = Expense(title: "Rent", category: .rent, amount: 100, date: day, createdBy: "u")
        let decodedExpense = try JSONDecoder().decode(Expense.self, from: JSONEncoder().encode(expense))
        #expect(decodedExpense.category == .rent)

        let attendance = AttendanceRecord(memberId: "m", memberName: "M", day: day, status: .leave, inAt: day, markedBy: "u")
        let decodedAttendance = try JSONDecoder().decode(AttendanceRecord.self, from: JSONEncoder().encode(attendance))
        #expect(decodedAttendance.id == attendance.id)
        #expect(decodedAttendance.status == .leave)
        #expect(decodedAttendance.inAt == day)

        let close = DayClose(date: day, expectedCash: 1, countedCash: 2, note: "n", carryForward: true, closedBy: "u", closedByName: "U")
        let decodedClose = try JSONDecoder().decode(DayClose.self, from: JSONEncoder().encode(close))
        #expect(decodedClose.id == close.id)
        #expect(decodedClose.difference == 1)

        let purchase = Purchase(number: "P", supplierId: "s", supplierName: "S", isReturn: true,
                                lines: [PurchaseLine(itemId: "i", itemName: "n", quantity: 1, unitCost: 5)],
                                total: 5, paid: 5, createdBy: "u")
        let decodedPurchase = try JSONDecoder().decode(Purchase.self, from: JSONEncoder().encode(purchase))
        #expect(decodedPurchase.isReturn)
        #expect(decodedPurchase.lines.count == 1)
    }

    // MARK: - Inventory sort directions

    @Test("Name sort ascending orders z to a, descending a to z")
    func nameSortDirections() {
        var items = [InventoryItem(name: "b"), InventoryItem(name: "c"), InventoryItem(name: "a")]
        items.sortByName(type: .ascending)
        #expect(items.map(\.name) == ["c", "b", "a"])
        items.sortByName(type: .descending)
        #expect(items.map(\.name) == ["a", "b", "c"])
    }

    @Test("Stock sort ascending puts the highest stock first, descending the lowest")
    func stockSortDirections() {
        var items = [InventoryItem(name: "x", currentStock: 5), InventoryItem(name: "y", currentStock: 9), InventoryItem(name: "z", currentStock: 1)]
        items.sortByStockLevel(type: .ascending)
        #expect(items.map(\.currentStock) == [9, 5, 1])
        items.sortByStockLevel(type: .descending)
        #expect(items.map(\.currentStock) == [1, 5, 9])
    }

    @Test("Date sorts treat missing dates as distant past in both directions")
    func dateSortDirections() {
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 200)
        var items = [InventoryItem(name: "none"), InventoryItem(name: "old", lastSoldDate: old, updatedAt: old),
                     InventoryItem(name: "recent", lastSoldDate: recent, updatedAt: recent)]

        items.sortByLastSoldDate(type: .ascending)
        #expect(items.map(\.name) == ["recent", "old", "none"])
        items.sortByLastSoldDate(type: .descending)
        #expect(items.map(\.name) == ["none", "old", "recent"])

        items.sortByUpdatedAt(type: .ascending)
        #expect(items.map(\.name) == ["recent", "old", "none"])
        items.sortByUpdatedAt(type: .descending)
        #expect(items.map(\.name) == ["none", "old", "recent"])
    }

    @Test("Missing dates render as Not Available")
    func missingDateStrings() {
        let item = InventoryItem(name: "n")
        #expect(item.lastSoldDateString == "Not Available")
        #expect(item.updatedAtString == "Not Available")
        let dated = InventoryItem(name: "n", lastSoldDate: Date(), updatedAt: Date())
        #expect(dated.lastSoldDateString != "Not Available")
        #expect(dated.updatedAtString != "Not Available")
    }

    @Test("Inventory item round-trips optional catalogue fields")
    func inventoryRoundTrip() throws {
        let item = InventoryItem(name: "Ring", currentStock: 3, barcode: "123", sellPrice: 10, costPrice: 5, wholesalePrice: 8,
                                 categoryId: "c", unit: "pc", lowStockThreshold: 1, imageURLs: ["a", "b"],
                                 designCode: "D1", variantsJSON: "[]", warrantyMonths: 6)
        let decoded = try JSONDecoder().decode(InventoryItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.barcode == "123")
        #expect(decoded.wholesalePrice == 8)
        #expect(decoded.imageURLs == ["a", "b"])
        #expect(decoded.designCode == "D1")
        #expect(decoded.variantsJSON == "[]")
        #expect(decoded.warrantyMonths == 6)
        #expect(decoded.lowStockThreshold == 1)
    }

    // MARK: - Customer tenure

    private func customer(daysAgo: Int) -> Customer {
        let created = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Customer(name: "A", phone: "1", createdAt: created.timeIntervalSince1970, lastPurchaseDate: nil,
                        totalSales: 0, totalAmountSpent: 0, updatedAt: nil, isDeleted: false)
    }

    @Test("Tenure around day, month and year boundaries")
    func tenureBoundaries() {
        #expect(customer(daysAgo: 1).tenure == "Customer for 1 days")
        #expect(customer(daysAgo: 29).tenure == "Customer for 29 days")
        #expect(customer(daysAgo: 59).tenure == "Customer for 1 month")
        #expect(customer(daysAgo: 60).tenure == "Customer for 2 months")
        #expect(customer(daysAgo: 364).tenure == "Customer for 12 months")
        #expect(customer(daysAgo: 395).tenure == "Customer for 1 year, 1 month")
        #expect(customer(daysAgo: 730).tenure == "Customer for 2 years")
        #expect(customer(daysAgo: 365 * 3 + 90).tenure == "Customer for 3 years, 3 months")
    }

    @Test("Customer with a future creation date does not crash")
    func tenureFuture() {
        #expect(!customer(daysAgo: -3).tenure.isEmpty)
    }

    // MARK: - Cashflow raw-string decoding

    @Test("Known category and sub-category strings decode, unknown sub-category falls back")
    func cashflowCategories() throws {
        let base = """
        {"id":"t","timestamp":0,"particulars":"p","amount":1,"transactionType":"debit","paymentMode":"cash",
         "category":"Utilities","subCategory":"%@","isDeleted":false,"updatedAt":0}
        """
        let known = try decode(CashflowTransaction.self, String(format: base, "Rent"))
        #expect(known.category == .utilities)
        #expect(known.subCategory == .rent)

        let unknown = try decode(CashflowTransaction.self, String(format: base, "Nonsense"))
        #expect(unknown.subCategory == .unknown)
    }

    @Test("Unknown transaction type or payment mode is rejected")
    func cashflowBadEnums() {
        let json = """
        {"id":"t","timestamp":0,"particulars":"p","amount":1,"transactionType":"refund","paymentMode":"cash",
         "category":"Utilities","isDeleted":false,"updatedAt":0}
        """
        #expect(throws: (any Error).self) { _ = try decode(CashflowTransaction.self, json) }
    }

    // MARK: - Theme and catalog

    @Test("User theme preference round-trips and org theme can differ in font when unlocked")
    func themeRoundTripAndFont() throws {
        let pref = UserThemePreference(accent: .slate, style: .bold, scheme: .dark, useOrgTheme: false, largerText: true, compactLists: true)
        let decoded = try JSONDecoder().decode(UserThemePreference.self, from: JSONEncoder().encode(pref))
        #expect(decoded == pref)

        let org = OrgSettings.Theme(accent: .ink, style: .clean, font: "Serif", locked: false)
        let theme = ThemeResolver.resolve(org: org, store: nil, user: pref, vertical: .kirana)
        #expect(theme.font == "Serif")
        #expect(theme.accent == .slate)
        #expect(theme.scheme == .dark)
    }

    @Test("Locked org that disallows dark mode forces light scheme")
    func lockedNoDark() {
        let org = OrgSettings.Theme(accent: .ink, locked: true, allowDark: false)
        let theme = ThemeResolver.resolve(org: org, store: nil, user: UserThemePreference(scheme: .dark), vertical: nil)
        #expect(theme.scheme == .light)
        #expect(theme.isLockedByOrg)
    }

    @Test("Remote config value kinds list all four shapes")
    func valueKinds() {
        #expect(RemoteConfigValueKind.allCases.map(\.rawValue) == ["bool", "string", "number", "versionGate"])
    }

    @Test("Version gate without min version is on for any version, including empty")
    func gateNoMin() {
        #expect(VersionGateValue(enabled: true).isOn(currentAppVersion: ""))
        #expect(VersionGateValue(enabled: true, minVersion: "1.0").isOn(currentAppVersion: "1.0.0"))
        #expect(!VersionGateValue(enabled: true, minVersion: "1.0.1").isOn(currentAppVersion: "1.0"))
    }
}
