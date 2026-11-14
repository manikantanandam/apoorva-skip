//
//  StorageCoverageTests.swift
//  ApoorvaOfflineStorage
//

import Testing
import Foundation
import ApoorvaModels
import SkipSQL
@testable import ApoorvaOfflineStorage

// MARK: - Helpers

private func exec(_ database: SkipSqlDatabase, _ sql: String, _ parameters: [SQLValue] = []) async throws {
    try await database.withContext { context in
        try context.exec(sql: sql, parameters: parameters)
    }
}

/// Dropping a table makes every later query on it fail, which exercises the error branches.
private func drop(_ database: SkipSqlDatabase, _ table: String) async throws {
    try await exec(database, "DROP TABLE \"\(table)\"")
}

private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

private func heldBill(_ id: String, updatedAt: Date? = nil, isDeleted: Bool = false) -> HeldBill {
    HeldBill(id: id, customerName: "Asha", customerPhone: "9", items: [], total: 50,
             createdAt: date(100), updatedAt: updatedAt, isDeleted: isDeleted)
}

private func transaction(_ id: String, subCategory: CashflowSubCategory? = nil, person: String? = nil) -> CashflowTransaction {
    CashflowTransaction(id: id, timestamp: date(1), particulars: "p", amount: 5, transactionType: .credit,
                        paymentMode: .cash, category: .salesRevenue, subCategory: subCategory,
                        fromAccountId: "a", toAccountId: "b", person: person, updatedAt: date(2),
                        timestampInMs: 1, updatedAtInMs: 2)
}

private func organization(_ id: String, name: String? = nil, accounts: [Account] = []) -> Organization {
    Organization(id: id, name: name ?? id, status: "active", createdAt: date(1), minVersion: "1.0",
                 currentTheme: "light", accentColor: "#000000", accounts: accounts,
                 updatedAt: date(2), establishedAtInMs: 1)
}

private func fullSale(_ id: String) -> Sale {
    var sale = Sale(id: id, staffId: "s", customerPhone: "1", customerName: "C",
                    items: [SaleItem(categoryId: "c", categoryName: "Cat", qty: 2, stickerPrice: 10, finalPrice: 9,
                                     discountType: .amount, doneByStaffId: "st", doneByName: "Staff",
                                     warrantyMonths: 6, weight: 1.5, unit: "kg", variant: "red")],
                    subtotal: 18, overallDiscountPercent: 1, overallDiscountAmount: 2, roundOff: 0.5,
                    netPayable: 16, payments: [.cash: 10, .upi: 6], timestamp: date(5), source: "pos",
                    status: "done", whatsappStatus: "none", updatedAt: date(6))
    sale.cancelReason = "wrong"
    sale.cancelledAt = date(7)
    sale.cancelledBy = "u"
    sale.editReason = "typo"
    sale.editedAt = date(8)
    sale.storeId = "store"
    sale.billNumber = "B-1"
    sale.returnOfSaleId = "s0"
    return sale
}

// MARK: - HeldBill

struct HeldBillLocalStorageTests {
    @Test func saveGetListAndDelete() async throws {
        let sut = HeldBillLocalStorage(database: try makeDatabase())
        try await sut.saveHeldBill(heldBill: heldBill("1"))
        try await sut.saveHeldBill(heldBill: heldBill("2", updatedAt: date(5)))
        #expect(try await sut.getHeldBill(id: "1")?.customerName == "Asha")
        #expect(try await sut.getHeldBill(id: "nope") == nil)
        #expect(try await sut.getHeldBills().count == 2)
        try await sut.deleteHeldBill(id: "1")
        #expect(try await sut.getHeldBill(id: "1") == nil)
    }

    @Test func updateWritesFieldsWithAndWithoutUpdatedAt() async throws {
        let sut = HeldBillLocalStorage(database: try makeDatabase())
        try await sut.saveHeldBill(heldBill: heldBill("1"))
        let changed = HeldBill(id: "1", customerName: "Changed", customerPhone: "8", items: [], total: 70,
                               createdAt: date(100), updatedAt: date(9))
        try await sut.updateHeldBill(heldBill: changed)
        let afterFirst = try await sut.getHeldBill(id: "1")
        #expect(afterFirst?.customerName == "Changed")
        #expect(afterFirst?.updatedAt == date(9))
        try await sut.updateHeldBill(heldBill: heldBill("1"))
        #expect(try await sut.getHeldBill(id: "1")?.updatedAt == nil)
    }

    @Test func markAsDeletedHidesFromList() async throws {
        let sut = HeldBillLocalStorage(database: try makeDatabase())
        try await sut.saveHeldBill(heldBill: heldBill("1"))
        try await sut.markAsDeleted(id: "1")
        #expect(try await sut.getHeldBills().isEmpty)
        #expect(try await sut.getHeldBill(id: "1")?.isDeleted == true)
    }

    @Test func saveManyHandlesEmptyAndUpserts() async throws {
        let sut = HeldBillLocalStorage(database: try makeDatabase())
        try await sut.saveHeldBills(heldBills: [])
        try await sut.saveHeldBills(heldBills: [heldBill("1"), heldBill("2", updatedAt: date(5))])
        try await sut.saveHeldBills(heldBills: [heldBill("1", updatedAt: date(7), isDeleted: true)])
        #expect(try await sut.getHeldBills().map(\.id) == ["2"])
    }

    @Test func storageErrorsAreHandled() async throws {
        let database = try makeDatabase()
        let sut = HeldBillLocalStorage(database: database)
        try await drop(database, "HeldBill")
        #expect(try await sut.getHeldBills().isEmpty)
        await #expect(throws: (any Error).self) { try await sut.saveHeldBills(heldBills: [heldBill("1")]) }
    }

    @Test func rowWithUnreadableItemsFallsBackToEmpty() async throws {
        let database = try makeDatabase()
        let sut = HeldBillLocalStorage(database: database)
        try await sut.saveHeldBill(heldBill: heldBill("1"))
        try await exec(database, "UPDATE \"HeldBill\" SET items = 'not json' WHERE id = '1'")
        #expect(try await sut.getHeldBill(id: "1")?.items.isEmpty == true)
    }
}

// MARK: - Cashflow

struct CashflowStorageCoverageTests {
    @Test func updateRewritesEveryField() async throws {
        let sut = CashflowTransactionLocalStorage(database: try makeDatabase())
        try await sut.saveCashflowTransaction(transaction: transaction("1"))
        var changed = transaction("1", subCategory: .painting, person: "Ravi")
        changed.isDeleted = true
        try await sut.updateCashflowTransaction(transaction: changed)
        let loaded = try #require(try await sut.getCashflowTransaction(id: "1"))
        #expect(loaded.subCategory == .painting)
        #expect(loaded.person == "Ravi")
        #expect(loaded.fromAccountId == "a")
        #expect(loaded.toAccountId == "b")
        #expect(loaded.timestampInMs == 1)
        #expect(loaded.updatedAtInMs == 2)
        #expect(loaded.isDeleted)
    }

    @Test func updateWithoutOptionalsStoresNulls() async throws {
        let sut = CashflowTransactionLocalStorage(database: try makeDatabase())
        try await sut.saveCashflowTransaction(transaction: transaction("1", subCategory: .painting, person: "Ravi"))
        try await sut.updateCashflowTransaction(transaction: transaction("1"))
        #expect(try await sut.getCashflowTransaction(id: "1")?.person == nil)
    }

    @Test func saveManyPersistsOptionalFields() async throws {
        let sut = CashflowTransactionLocalStorage(database: try makeDatabase())
        try await sut.saveCashflowTransactions(transactions: [
            transaction("1", subCategory: .woodwork, person: "Ravi"), transaction("2")
        ])
        #expect(try await sut.getCashflowTransaction(id: "1")?.person == "Ravi")
        #expect(try await sut.getCashflowTransaction(id: "1")?.subCategory == .woodwork)
        #expect(try await sut.getCashflowTransaction(id: "2")?.person == nil)
    }

    @Test func unknownStoredValuesDecodeToUnknown() async throws {
        let database = try makeDatabase()
        let sut = CashflowTransactionLocalStorage(database: database)
        try await sut.saveCashflowTransaction(transaction: transaction("1", subCategory: .painting))
        try await exec(database, """
            UPDATE "CashflowTransaction" SET transactionType = 'zzz', paymentMode = 'zzz', category = 'zzz',
            subCategory = 'zzz', fromAccountId = NULL, toAccountId = NULL, timestampInMs = NULL, updatedAtInMs = NULL
            WHERE id = '1'
            """)
        let loaded = try #require(try await sut.getCashflowTransaction(id: "1"))
        #expect(loaded.transactionType == .unknown)
        #expect(loaded.paymentMode == .unknown)
        #expect(loaded.category == .unknown)
        #expect(loaded.subCategory == .unknown)
        #expect(loaded.fromAccountId == "" && loaded.toAccountId == "")
        #expect(loaded.timestampInMs == 0 && loaded.updatedAtInMs == 0)

        try await exec(database, "UPDATE \"CashflowTransaction\" SET subCategory = NULL WHERE id = '1'")
        #expect(try await sut.getCashflowTransaction(id: "1")?.subCategory == .unknown)
    }

    @Test func storageErrorsAreHandled() async throws {
        let database = try makeDatabase()
        let sut = CashflowTransactionLocalStorage(database: database)
        try await drop(database, "CashflowTransaction")
        #expect(try await sut.getCashflowTransactions().isEmpty)
        await #expect(throws: (any Error).self) { try await sut.saveCashflowTransactions(transactions: [transaction("1")]) }
    }
}

// MARK: - Organization

struct OrganizationStorageCoverageTests {
    @Test func updateRewritesEveryField() async throws {
        let sut = OrganizationLocalStorage(database: try makeDatabase())
        try await sut.saveOrganization(organization: organization("a"))
        try await sut.updateOrganization(organization: organization("a", name: "Renamed",
                                                                    accounts: [Account(name: "Cash", type: .cash, currentBalance: 5)]))
        let loaded = try #require(try await sut.getOrganization(orgId: "a"))
        #expect(loaded.name == "Renamed")
        #expect(loaded.accounts.count == 1)
        #expect(loaded.establishedAtInMs == 1)
    }

    @Test func missingOptionalColumnsDecodeToDefaults() async throws {
        let database = try makeDatabase()
        let sut = OrganizationLocalStorage(database: database)
        try await sut.saveOrganization(organization: organization("a", accounts: [Account(name: "Cash", type: .cash, currentBalance: 5)]))
        try await exec(database, "UPDATE \"Organization\" SET accounts = NULL, minVersion = NULL, currentTheme = NULL, accentColor = NULL")
        let loaded = try #require(try await sut.getOrganization(orgId: "a"))
        #expect(loaded.accounts.isEmpty)
        #expect(loaded.minVersion == "" && loaded.currentTheme == "" && loaded.accentColor == "")
        try await exec(database, "UPDATE \"Organization\" SET accounts = 'not json'")
        #expect(try await sut.getOrganization(orgId: "a")?.accounts.isEmpty == true)
    }

    @Test func markAsDeletedSetsFlag() async throws {
        let sut = OrganizationLocalStorage(database: try makeDatabase())
        try await sut.saveOrganization(organization: organization("a"))
        try await sut.markAsDeleted(orgId: "a")
        #expect(try await sut.getOrganization(orgId: "a")?.isDeleted == true)
    }

    @Test func storageErrorsAreHandled() async throws {
        let database = try makeDatabase()
        let sut = OrganizationLocalStorage(database: database)
        try await drop(database, "Organization")
        #expect(try await sut.getOrganizations().isEmpty)
        await #expect(throws: (any Error).self) { try await sut.getOrganization(orgId: "a") }
    }
}

// MARK: - Sale

struct SaleStorageCoverageTests {
    @Test func fullSaleRoundTrips() async throws {
        let sut = SaleLocalStorage(database: try makeDatabase())
        try await sut.saveSale(sale: fullSale("s1"))
        let loaded = try #require(try await sut.getSale(id: "s1"))
        #expect(loaded.items.count == 1)
        #expect(loaded.items.first?.variant == "red")
        #expect(loaded.payments[.upi] == 6)
        #expect(loaded.cancelReason == "wrong" && loaded.cancelledBy == "u" && loaded.cancelledAt == date(7))
        #expect(loaded.editReason == "typo" && loaded.editedAt == date(8))
        #expect(loaded.storeId == "store" && loaded.billNumber == "B-1" && loaded.returnOfSaleId == "s0")
        #expect(loaded.updatedAt == date(6))
    }

    @Test func unreadableJSONColumnsFallBackToEmpty() async throws {
        let database = try makeDatabase()
        let sut = SaleLocalStorage(database: database)
        try await sut.saveSale(sale: fullSale("s1"))
        try await exec(database, "UPDATE \"Sale\" SET items = 'bad', payments = 'bad'")
        let loaded = try #require(try await sut.getSale(id: "s1"))
        #expect(loaded.items.isEmpty && loaded.payments.isEmpty)
    }

    @Test func markAsDeletedMissingSaleIsNoOp() async throws {
        let sut = SaleLocalStorage(database: try makeDatabase())
        try await sut.markAsDeleted(id: "missing")
        #expect(try await sut.getSales().isEmpty)
    }

    @Test func saveSalesSkipsSalesWithoutId() async throws {
        let sut = SaleLocalStorage(database: try makeDatabase())
        var noId = fullSale("x")
        noId = Sale(id: "", staffId: "s", customerPhone: "1", customerName: "C", items: [], subtotal: 1,
                    overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 1, payments: [:],
                    timestamp: date(1), source: "pos", status: "done", whatsappStatus: "none")
        try await sut.saveSales(sales: [noId])
        #expect(try await sut.getSales().isEmpty)
        try await sut.saveSales(sales: [noId, fullSale("ok")])
        #expect(try await sut.getSales().map(\.id) == ["ok"])
    }

    @Test func listErrorReturnsEmpty() async throws {
        let database = try makeDatabase()
        let sut = SaleLocalStorage(database: database)
        try await drop(database, "Sale")
        #expect(try await sut.getSales().isEmpty)
    }
}

// MARK: - Customer

struct CustomerStorageCoverageTests {
    private func fullCustomer(_ phone: String) -> Customer {
        Customer(name: "Asha", phone: phone, createdAt: 1, lastPurchaseDate: 2, totalSales: 3, totalAmountSpent: 40,
                 updatedAt: 5, isDeleted: false, creditLimit: 500, birthday: 6, dueBalance: 7,
                 priceTier: "wholesale", notes: "vip", whatsappReceipts: false)
    }

    @Test func fullCustomerRoundTrips() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.saveCustomer(customer: fullCustomer("1"))
        let loaded = try #require(try await sut.getCustomer(phoneNumber: "1"))
        #expect(loaded.creditLimit == 500 && loaded.birthday == 6 && loaded.dueBalance == 7)
        #expect(loaded.priceTier == "wholesale" && loaded.notes == "vip" && !loaded.whatsappReceipts)
    }

    @Test func lookupByNameUpdateAndHardDelete() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.saveCustomer(customer: fullCustomer("1"))
        #expect(try await sut.getCustomer(name: "Asha")?.phone == "1")
        #expect(try await sut.getCustomer(name: "Nobody") == nil)
        var changed = fullCustomer("1")
        changed.name = "Renamed"
        try await sut.updateCustomer(customer: changed)
        #expect(try await sut.getCustomer(phoneNumber: "1")?.name == "Renamed")
        try await sut.deleteCustomer(phoneNumber: "1")
        #expect(try await sut.getCustomer(phoneNumber: "1") == nil)
    }

    @Test func markAsDeletedMissingCustomerIsNoOp() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.markAsDeleted(id: "missing")
        #expect(try await sut.getCustomers().isEmpty)
    }

    @Test func nullColumnsDecodeToDefaults() async throws {
        let database = try makeDatabase()
        let sut = CustomerLocalStorage(database: database)
        try await sut.saveCustomer(customer: fullCustomer("1"))
        try await exec(database, """
            UPDATE "Customer" SET name = NULL, createdAt = NULL, totalSales = NULL, totalAmountSpent = NULL,
            isDeleted = NULL, dueBalance = NULL, whatsappReceipts = NULL
            """)
        let loaded = try #require(try await sut.getCustomer(phoneNumber: "1"))
        #expect(loaded.name == "" && loaded.createdAt == 0 && loaded.totalSales == 0)
        #expect(loaded.dueBalance == 0 && loaded.whatsappReceipts && !loaded.isDeleted)
    }

    @Test func listErrorReturnsEmpty() async throws {
        let database = try makeDatabase()
        let sut = CustomerLocalStorage(database: database)
        try await drop(database, "Customer")
        #expect(try await sut.getCustomers().isEmpty)
    }
}

// MARK: - Inventory

struct InventoryStorageCoverageTests {
    @Test func fullItemRoundTrips() async throws {
        let sut = InventoryItemLocalStorage(database: try makeDatabase())
        var item = InventoryItem(id: "1", name: "Pen", currentStock: 3, lastSoldDate: date(5), isHotkey: true, updatedAt: date(6))
        item.barcode = "b"; item.sellPrice = 1; item.costPrice = 2; item.wholesalePrice = 3
        item.categoryId = "c"; item.unit = "kg"; item.lowStockThreshold = 4; item.imageURLs = ["u1", "u2"]
        item.designCode = "d"; item.variantsJSON = "[]"; item.warrantyMonths = 12
        try await sut.saveInventoryItem(item: item)
        let loaded = try #require(try await sut.getInventoryItem(id: "1"))
        #expect(loaded.isHotkey && loaded.lastSoldDate == date(5))
        #expect(loaded.imageURLs == ["u1", "u2"] && loaded.lowStockThreshold == 4 && loaded.warrantyMonths == 12)
        #expect(loaded.designCode == "d" && loaded.variantsJSON == "[]" && loaded.unit == "kg" && loaded.categoryId == "c")
        #expect(loaded.costPrice == 2 && loaded.wholesalePrice == 3)
    }

    @Test func nullColumnsDecodeToDefaults() async throws {
        let database = try makeDatabase()
        let sut = InventoryItemLocalStorage(database: database)
        try await sut.saveInventoryItem(item: InventoryItem(id: "1", name: "Pen"))
        try await exec(database, """
            UPDATE "ItemCategory" SET name = NULL, currentStock = NULL, billMachineNumber = NULL,
            isHotkey = NULL, isDeleted = NULL
            """)
        let loaded = try #require(try await sut.getInventoryItem(id: "1"))
        #expect(loaded.name == "" && loaded.currentStock == 0 && loaded.billMachineNumber == 0)
        #expect(!loaded.isHotkey && !loaded.isDeleted)
    }

    @Test func markAsDeletedMissingItemIsNoOp() async throws {
        let sut = InventoryItemLocalStorage(database: try makeDatabase())
        try await sut.markAsDeleted(id: "missing")
        #expect(try await sut.getInventoryItems().isEmpty)
    }

    @Test func listErrorReturnsEmpty() async throws {
        let database = try makeDatabase()
        let sut = InventoryItemLocalStorage(database: database)
        try await drop(database, "ItemCategory")
        #expect(try await sut.getInventoryItems().isEmpty)
    }
}

// MARK: - Daily cashflow summary

struct DailySummaryStorageCoverageTests {
    private func summary(_ seconds: TimeInterval, locked: Bool = false) -> DailyCashflowSummary {
        DailyCashflowSummary(date: date(seconds),
                             openingBalances: [AccountBalance(id: "a", name: "Cash", balance: 1)],
                             closingBalances: [AccountBalance(id: "a", name: "Cash", balance: 2)],
                             updatedAt: 3, locked: locked)
    }

    @Test func roundTripsBalancesAndLock() async throws {
        let sut = DailyCashflowSummaryLocalStorage(database: try makeDatabase())
        let value = summary(86_400 * 10, locked: true)
        try await sut.saveDailyCashflowSummary(summary: value)
        let loaded = try #require(try await sut.getDailyCashflowSummary(id: value.id))
        #expect(loaded.locked)
        #expect(loaded.closingBalances.first?.balance == 2)
        #expect(loaded.openingBalances.first?.name == "Cash")
    }

    @Test func updateRewritesFields() async throws {
        let sut = DailyCashflowSummaryLocalStorage(database: try makeDatabase())
        let value = summary(86_400 * 10)
        try await sut.saveDailyCashflowSummary(summary: value)
        try await sut.updateDailyCashflowSummary(summary: DailyCashflowSummary(
            date: value.date, openingBalances: [], closingBalances: [], updatedAt: 9, locked: true))
        let loaded = try #require(try await sut.getDailyCashflowSummary(id: value.id))
        #expect(loaded.locked && loaded.updatedAt == 9 && loaded.closingBalances.isEmpty)
    }

    @Test func unreadableBalancesFallBackToEmptyAndNullsToDefaults() async throws {
        let database = try makeDatabase()
        let sut = DailyCashflowSummaryLocalStorage(database: database)
        let value = summary(86_400 * 10)
        try await sut.saveDailyCashflowSummary(summary: value)
        try await exec(database, "UPDATE \"DailyCashflowSummary\" SET openingBalances = 'bad', closingBalances = 'bad', updatedAt = NULL, locked = NULL")
        let loaded = try #require(try await sut.getDailyCashflowSummary(id: value.id))
        #expect(loaded.openingBalances.isEmpty && loaded.closingBalances.isEmpty)
        #expect(loaded.updatedAt == 0 && !loaded.locked)
    }

    @Test func storageErrorsAreHandled() async throws {
        let database = try makeDatabase()
        let sut = DailyCashflowSummaryLocalStorage(database: database)
        try await drop(database, "DailyCashflowSummary")
        #expect(try await sut.getDailyCashflowSummaries().isEmpty)
        await #expect(throws: (any Error).self) { try await sut.getDailyCashflowSummary(id: "x") }
        await #expect(throws: (any Error).self) { try await sut.saveDailyCashflowSummaries(summaries: [summary(86_400)]) }
    }
}

// MARK: - Small models and utilities

struct SmallStorageTypeTests {
    @Test func syncStateDefaultsAndRowMapping() async throws {
        #expect(SyncState(entityName: "Sale").lastSyncTimestamp == 0)
        let database = try makeDatabase()
        try await database.withContext { context in
            try context.insert(SyncState(entityName: "X", lastSyncTimestamp: 5), upsert: true)
        }
        let loaded = try await database.withContext { context in
            try context.fetch(SyncState.self, primaryKeys: [.text("X")])
        }
        #expect(loaded?.lastSyncTimestamp == 5)
    }

    @Test func orgDocumentRecordRoundTripsWithAndWithoutUpdatedAt() async throws {
        let database = try makeDatabase()
        let withDate = OrgDocumentRecord(collection: "c", id: "1", payload: "{}", updatedAt: 5, isDeleted: true)
        let withoutDate = OrgDocumentRecord(collection: "c", id: "2", payload: "{}", updatedAt: nil, isDeleted: false)
        try await database.withContext { context in
            try context.insert(withDate, upsert: true)
            try context.insert(withoutDate, upsert: true)
        }
        let first = try await database.withContext { try $0.fetch(OrgDocumentRecord.self, primaryKeys: [.text("c"), .text("1")]) }
        let second = try await database.withContext { try $0.fetch(OrgDocumentRecord.self, primaryKeys: [.text("c"), .text("2")]) }
        #expect(first == withDate)
        #expect(second == withoutDate)
    }

    @Test func internalTransferRoundTrips() async throws {
        let database = try makeDatabase()
        let transfer = InternalTransfer(id: "t1", fromAccountId: "a", toAccountId: "b", amount: 25,
                                        transferType: "cash", timestamp: date(5), updatedAt: date(6), isDeleted: true)
        let loaded = try await database.withContext { context in
            try context.createTableIfNotExists(InternalTransfer.self)
            try context.insert(transfer)
            return try context.fetch(InternalTransfer.self, primaryKeys: [.text("t1")])
        }
        #expect(loaded?.amount == 25)
        #expect(loaded?.toAccountId == "b" && loaded?.transferType == "cash")
        #expect(loaded?.timestamp == date(5) && loaded?.updatedAt == date(6))
        #expect(loaded?.isDeleted == true)
    }

    @Test func userDefaultsStorageRoundTripsAndRemoves() throws {
        let suite = "storage-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sut = UserDefaultsStorage(defaults: defaults)

        #expect(try sut.get(forKey: "k", as: [String].self) == nil)
        try sut.set(["a", "b"], forKey: "k")
        #expect(try sut.get(forKey: "k", as: [String].self) == ["a", "b"])
        sut.remove(forKey: "k")
        #expect(try sut.get(forKey: "k", as: [String].self) == nil)
    }

    @Test func userDefaultsStorageRemovesOnlyPrefixedKeys() throws {
        let suite = "storage-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sut = UserDefaultsStorage(defaults: defaults)

        try sut.set(1, forKey: "user_a")
        try sut.set(2, forKey: "user_b")
        try sut.set(3, forKey: "other")
        sut.removeAll(matchingPrefix: "user_")
        #expect(try sut.get(forKey: "user_a", as: Int.self) == nil)
        #expect(try sut.get(forKey: "user_b", as: Int.self) == nil)
        #expect(try sut.get(forKey: "other", as: Int.self) == 3)
    }
}
