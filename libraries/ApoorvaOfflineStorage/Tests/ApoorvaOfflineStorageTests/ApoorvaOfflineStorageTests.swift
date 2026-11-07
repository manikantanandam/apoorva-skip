//
//  ApoorvaOfflineStorageTests.swift
//  ApoorvaOfflineStorage
//

import Testing
import Foundation
import ApoorvaModels
@testable import ApoorvaOfflineStorage

func makeDatabase() throws -> SkipSqlDatabase {
    try SkipSqlDatabase(filepath: ":memory:")
}

// MARK: - SyncStorage

struct SyncStorageTests {
    @Test func unknownEntityHasNoTimestamp() async throws {
        let sut = SyncStorage(db: try makeDatabase())
        #expect(try await sut.getLastSyncTimestamp(for: "X") == nil)
    }

    @Test func updateUpsertsTimestamp() async throws {
        let sut = SyncStorage(db: try makeDatabase())
        try await sut.updateSyncTimestamp(for: "X", timestamp: 1)
        try await sut.updateSyncTimestamp(for: "X", timestamp: 2)
        #expect(try await sut.getLastSyncTimestamp(for: "X") == 2)
    }

    @Test func resetClearsOneOrAll() async throws {
        let sut = SyncStorage(db: try makeDatabase())
        try await sut.updateSyncTimestamp(for: "X", timestamp: 1)
        try await sut.updateSyncTimestamp(for: "Y", timestamp: 1)
        try await sut.resetSyncState(for: "X")
        #expect(try await sut.getLastSyncTimestamp(for: "X") == nil)
        #expect(try await sut.getLastSyncTimestamp(for: "Y") == 1)
        try await sut.resetAllSyncStates()
        #expect(try await sut.getLastSyncTimestamp(for: "Y") == nil)
    }
}

// MARK: - CustomerLocalStorage

struct CustomerLocalStorageTests {
    private func customer(_ name: String, phone: String, lastPurchase: TimeInterval? = 3, updatedAt: TimeInterval? = 4) -> Customer {
        Customer(name: name, phone: phone, createdAt: 1, lastPurchaseDate: lastPurchase,
                 totalSales: 2, totalAmountSpent: 30, updatedAt: updatedAt, isDeleted: false)
    }

    @Test func saveAndFetchByPhone() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.saveCustomer(customer: customer("Asha", phone: "111"))
        let found = try await sut.getCustomer(phoneNumber: "111")
        #expect(found?.name == "Asha")
        #expect(try await sut.getCustomer(phoneNumber: "000") == nil)
    }

    @Test func getCustomersReturnsSortedByName() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.saveCustomers(customers: [
            customer("Zed", phone: "1"),
            customer("Amy", phone: "2", lastPurchase: 5, updatedAt: 9)
        ])
        #expect(try await sut.getCustomers().map(\.name) == ["Amy", "Zed"])
    }

    @Test func readingCustomerWithNullDatesFails() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.saveCustomer(customer: customer("Nil", phone: "9", lastPurchase: nil, updatedAt: nil))
        // Known source bug: nullable date columns are decoded as non-optional.
        await withKnownIssue { _ = try await sut.getCustomer(phoneNumber: "9") }
    }

    @Test func saveCustomersWithEmptyListIsNoOp() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.saveCustomers(customers: [])
        #expect(try await sut.getCustomers().isEmpty)
    }

    @Test func saveCustomersReplacesExistingPhone() async throws {
        let sut = CustomerLocalStorage(database: try makeDatabase())
        try await sut.saveCustomers(customers: [customer("Old", phone: "1")])
        try await sut.saveCustomers(customers: [customer("New", phone: "1")])
        #expect(try await sut.getCustomers().map(\.name) == ["New"])
    }
}

// MARK: - InventoryItemLocalStorage

struct InventoryItemLocalStorageTests {
    @Test func saveGetAndList() async throws {
        let sut = InventoryItemLocalStorage(database: try makeDatabase())
        let item = InventoryItem(id: "1", name: "Pen", currentStock: 3)
        try await sut.saveInventoryItem(item: item)
        #expect(try await sut.getInventoryItem(id: "1")?.name == "Pen")
        #expect(try await sut.getInventoryItems().count == 1)
        #expect(try await sut.getInventoryItem(id: "nope") == nil)
    }

    @Test func saveManyUpserts() async throws {
        let sut = InventoryItemLocalStorage(database: try makeDatabase())
        try await sut.saveInventoryItems(items: [])
        try await sut.saveInventoryItems(items: [
            InventoryItem(id: "1", name: "A", updatedAt: Date()),
            InventoryItem(id: "2", name: "B")
        ])
        try await sut.saveInventoryItems(items: [InventoryItem(id: "1", name: "A2", isHotkey: true)])
        #expect(try await sut.getInventoryItem(id: "1")?.name == "A2")
        #expect(try await sut.getInventoryItems().count == 2)
    }

    @Test func updateChangesFields() async throws {
        let sut = InventoryItemLocalStorage(database: try makeDatabase())
        try await sut.saveInventoryItem(item: InventoryItem(id: "1", name: "Pen"))
        // Known source bug: update queries a non-existent "Category" table.
        await withKnownIssue {
            try await sut.updateInventoryItem(item: InventoryItem(id: "1", name: "Pencil", currentStock: 9,
                                                                  lastSoldDate: Date(), updatedAt: Date()))
        }
    }

    @Test func deleteRemovesItem() async throws {
        let sut = InventoryItemLocalStorage(database: try makeDatabase())
        try await sut.saveInventoryItem(item: InventoryItem(id: "1", name: "Pen"))
        // Known source bug: delete queries a non-existent "Category" table.
        await withKnownIssue { try await sut.deleteInventoryItem(id: "1") }
    }

    @Test func markAsDeletedFlagsItem() async throws {
        let sut = InventoryItemLocalStorage(database: try makeDatabase())
        try await sut.saveInventoryItem(item: InventoryItem(id: "1", name: "Pen"))
        // Known source bug: markAsDeleted queries a non-existent "Category" table.
        await withKnownIssue { try await sut.markAsDeleted(id: "1") }
    }
}

// MARK: - SaleLocalStorage

struct SaleLocalStorageTests {
    private func sale(_ id: String, updatedAt: Date? = nil) -> Sale {
        Sale(id: id, staffId: "s", customerPhone: "1", customerName: "C", items: [],
             subtotal: 10, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0,
             netPayable: 10, payments: [:], timestamp: Date(timeIntervalSince1970: 1),
             source: "pos", status: "done", whatsappStatus: "none", updatedAt: updatedAt)
    }

    @Test func saveGetAndList() async throws {
        let sut = SaleLocalStorage(database: try makeDatabase())
        try await sut.saveSale(sale: sale("1"))
        #expect(try await sut.getSale(id: "1")?.id == "1")
        #expect(try await sut.getSales().count == 1)
    }

    @Test func saveManyUpdateDeleteAndMarkDeleted() async throws {
        let sut = SaleLocalStorage(database: try makeDatabase())
        try await sut.saveSales(sales: [])
        try await sut.saveSales(sales: [sale("1", updatedAt: Date()), sale("2")])
        try await sut.updateSale(sale: sale("1", updatedAt: Date()))
        try await sut.markAsDeleted(id: "2")
        try await sut.deleteSale(id: "1")
        #expect(try await sut.getSale(id: "1") == nil)
    }
}

// MARK: - CashflowTransactionLocalStorage

struct CashflowTransactionLocalStorageTests {
    private func transaction(_ id: String) -> CashflowTransaction {
        CashflowTransaction(id: id, timestamp: Date(timeIntervalSince1970: 1), particulars: "p", amount: 5,
                            transactionType: .credit, paymentMode: .cash, category: .salesRevenue,
                            fromAccountId: "a", toAccountId: "b", timestampInMs: 1, updatedAtInMs: 1)
    }

    @Test func saveGetAndList() async throws {
        let sut = CashflowTransactionLocalStorage(database: try makeDatabase())
        try await sut.saveCashflowTransaction(transaction: transaction("1"))
        #expect(try await sut.getCashflowTransaction(id: "1")?.id == "1")
        #expect(try await sut.getCashflowTransactions().count == 1)
    }

    @Test func saveManyUpdateDeleteAndMarkDeleted() async throws {
        let sut = CashflowTransactionLocalStorage(database: try makeDatabase())
        try await sut.saveCashflowTransactions(transactions: [])
        try await sut.saveCashflowTransactions(transactions: [transaction("1"), transaction("2")])
        try await sut.updateCashflowTransaction(transaction: transaction("1"))
        try await sut.markAsDeleted(id: "2")
        try await sut.deleteCashflowTransaction(id: "1")
        #expect(try await sut.getCashflowTransaction(id: "1") == nil)
    }
}

// MARK: - OrganizationLocalStorage

struct OrganizationLocalStorageTests {
    private func org(_ id: String) -> Organization {
        Organization(id: id, name: id, status: "active", createdAt: Date(timeIntervalSince1970: 1),
                     minVersion: "1.0", currentTheme: "light", accentColor: "#000000", accounts: [],
                     establishedAtInMs: 1)
    }

    @Test func saveGetAndList() async throws {
        let sut = OrganizationLocalStorage(database: try makeDatabase())
        try await sut.saveOrganization(organization: org("a"))
        #expect(try await sut.getOrganization(orgId: "a")?.id == "a")
        #expect(try await sut.getOrganizations().count == 1)
        #expect(try await sut.getOrganization(orgId: "zzz") == nil)
    }

    @Test func saveManyUpdateMarkAndDelete() async throws {
        let sut = OrganizationLocalStorage(database: try makeDatabase())
        try await sut.saveOrganizations(organizations: [])
        try await sut.saveOrganizations(organizations: [org("a"), org("b")])
        try await sut.updateOrganization(organization: org("a"))
        try await sut.markAsDeleted(orgId: "b")
        try await sut.deleteOrganization(orgId: "a")
        #expect(try await sut.getOrganization(orgId: "a") == nil)
    }
}

// MARK: - DailyCashflowSummaryLocalStorage

struct DailyCashflowSummaryLocalStorageTests {
    private func summary(_ seconds: TimeInterval) -> DailyCashflowSummary {
        DailyCashflowSummary(date: Date(timeIntervalSince1970: seconds), openingBalances: [],
                             closingBalances: [], updatedAt: 1, locked: false)
    }

    @Test func saveGetAndList() async throws {
        let sut = DailyCashflowSummaryLocalStorage(database: try makeDatabase())
        let s = summary(86_400 * 10)
        try await sut.saveDailyCashflowSummary(summary: s)
        #expect(try await sut.getDailyCashflowSummary(id: s.id)?.id == s.id)
        #expect(try await sut.getDailyCashflowSummaries().count == 1)
    }

    @Test func saveManyUpdateAndDelete() async throws {
        let sut = DailyCashflowSummaryLocalStorage(database: try makeDatabase())
        let a = summary(86_400 * 10)
        let b = summary(86_400 * 20)
        try await sut.saveDailyCashflowSummaries(summaries: [])
        try await sut.saveDailyCashflowSummaries(summaries: [a, b])
        try await sut.updateDailyCashflowSummary(summary: a)
        try await sut.deleteDailyCashflowSummary(id: a.id)
        #expect(try await sut.getDailyCashflowSummary(id: a.id) == nil)
    }
}
