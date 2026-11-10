//
//  MigrationAndOrgCollectionTests.swift
//  ApoorvaOfflineStorage
//

import Testing
import Foundation
import ApoorvaModels
import SkipSQL
@testable import ApoorvaOfflineStorage

struct SchemaMigrationTests {

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("migration-\(UUID().uuidString).sqlite").path
    }

    /// Builds a database the way installs looked before migrations: v1 tables only, user_version 0.
    private func makeLegacyDatabase(at path: String) throws {
        let context = try SQLContext(path: path, flags: [.create, .readWrite], configuration: .platform)
        try context.exec(sql: """
            CREATE TABLE "Customer" ("phone" TEXT PRIMARY KEY, "name" TEXT, "createdAt" REAL, "lastPurchaseDate" REAL,
            "totalSales" INTEGER, "totalAmountSpent" REAL, "updatedAt" REAL, "isDeleted" INTEGER)
            """)
        try context.exec(sql: "INSERT INTO \"Customer\" VALUES ('99', 'Legacy', 1, 2, 3, 40, 5, 0)")
        try context.exec(sql: "CREATE TABLE \"SyncState\" (\"entityName\" TEXT PRIMARY KEY, \"lastSyncTimestamp\" REAL)")
        try context.exec(sql: "INSERT INTO \"SyncState\" VALUES ('Sale', 123), ('Customer', 456)")
        try context.close()
    }

    @Test func migratesLegacyDatabaseKeepingRows() async throws {
        let path = tempPath()
        try makeLegacyDatabase(at: path)

        let database = try SkipSqlDatabase(filepath: path)
        #expect(await database.schemaVersion == Int64(SchemaMigrations.all.count))

        let storage = CustomerLocalStorage(database: database)
        let legacy = try await storage.getCustomer(phoneNumber: "99")
        #expect(legacy?.name == "Legacy")
        #expect(legacy?.dueBalance == 0)

        let sync = SyncStorage(db: database)
        #expect(try await sync.getLastSyncTimestamp(for: "Sale") == nil)
        #expect(try await sync.getLastSyncTimestamp(for: "Customer") == 456)
    }

    @Test func migrationIsIdempotent() async throws {
        let path = tempPath()
        try makeLegacyDatabase(at: path)
        _ = try SkipSqlDatabase(filepath: path)
        let reopened = try SkipSqlDatabase(filepath: path)
        try await reopened.migrate()
        #expect(await reopened.schemaVersion == Int64(SchemaMigrations.all.count))
    }

    @Test func clearAllLocalDataEmptiesEveryTable() async throws {
        let database = try makeDatabase()
        let storage = CustomerLocalStorage(database: database)
        try await storage.saveCustomer(customer: Customer(name: "A", phone: "1", createdAt: 1, lastPurchaseDate: nil,
                                                          totalSales: 0, totalAmountSpent: 0, updatedAt: nil, isDeleted: false))
        let ledger = OrgCollectionLocalStorage<CustomerLedgerEntry>(database: database)
        try await ledger.upsert(CustomerLedgerEntry(customerPhone: "1", customerName: "A", kind: .opening, amount: 10, createdBy: "u"))

        try await database.clearAllLocalData()

        #expect(try await storage.getCustomers().isEmpty)
        #expect(try await ledger.all().isEmpty)
    }
}

struct OrgCollectionLocalStorageTests {

    private func entry(_ id: String, amount: Double, phone: String = "1") -> CustomerLedgerEntry {
        CustomerLedgerEntry(id: id, customerPhone: phone, customerName: "A", kind: .sale, amount: amount, createdBy: "u")
    }

    @Test func upsertAndReadBack() async throws {
        let sut = OrgCollectionLocalStorage<CustomerLedgerEntry>(database: try makeDatabase())
        try await sut.upsert(entry("a", amount: 100))
        try await sut.upsert(entry("a", amount: 150))
        let all = try await sut.all()
        #expect(all.count == 1)
        #expect(all.first?.amount == 150)
    }

    @Test func collectionsAreIsolated() async throws {
        let database = try makeDatabase()
        let ledger = OrgCollectionLocalStorage<CustomerLedgerEntry>(database: database)
        let movements = OrgCollectionLocalStorage<StockMovement>(database: database)
        try await ledger.upsert(entry("same-id", amount: 1))
        try await movements.upsert(StockMovement(id: "same-id", itemId: "i", itemName: "Pen", delta: -1, reason: .sale, createdBy: "u"))
        #expect(try await ledger.all().count == 1)
        #expect(try await movements.all().count == 1)
        #expect(try await ledger.get(id: "same-id")?.amount == 1)
    }

    @Test func markDeletedHidesUnlessRequested() async throws {
        let sut = OrgCollectionLocalStorage<CustomerLedgerEntry>(database: try makeDatabase())
        try await sut.upsertAll([entry("a", amount: 10), entry("b", amount: 20)])
        try await sut.markDeleted(id: "a")
        #expect(try await sut.all().map(\.id) == ["b"])
        #expect(try await sut.all(includeDeleted: true).count == 2)
    }

    @Test func ledgerBalanceSumsSignedAmounts() {
        let entries = [entry("a", amount: 500), entry("b", amount: -200), entry("c", amount: 50)]
        #expect(entries.balance == 350)
    }
}
