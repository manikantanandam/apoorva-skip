//
//  ApoorvaServicesTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import FirebaseFirestore
import ApoorvaModels
@testable import ApoorvaServices

// MARK: - Mock store

final class MockFirestoreStore: FirestoreStoring, @unchecked Sendable {
    /// Full document path -> field map.
    var documents: [String: [String: Any]] = [:]
    var writes: [(path: String, data: [String: Any], merge: Bool)] = []
    var updates: [(path: String, fields: [String: Any])] = []

    func put<T: Encodable>(_ value: T, at path: String) throws {
        documents[path] = try Firestore.Encoder().encode(value)
    }

    func getDocuments(collection path: String, query: StoreQuery) async throws -> [StoreDocument] {
        documents
            .filter { key, _ in
                guard key.hasPrefix(path + "/") else { return false }
                return !key.dropFirst(path.count + 1).contains("/")
            }
            .filter { _, data in matches(data, query) }
            .map { StoreDocument(id: String($0.key.split(separator: "/").last ?? ""), data: $0.value) }
    }

    func getDocument(path: String) async throws -> StoreDocument? {
        documents[path].map { StoreDocument(id: String(path.split(separator: "/").last ?? ""), data: $0) }
    }

    func setData(_ data: [String: Any], path: String, merge: Bool) throws {
        writes.append((path, data, merge))
        documents[path] = data
    }

    func updateData(_ fields: [String: Any], path: String) async throws {
        updates.append((path, fields))
    }

    private func matches(_ data: [String: Any], _ query: StoreQuery) -> Bool {
        guard !query.conditions.isEmpty else { return true }
        let results = query.conditions.map { condition -> Bool in
            switch condition {
            case let .greaterThan(field, date):
                guard let value = dateValue(of: data[field]) else { return false }
                return value > date
            case let .isIn(field, values):
                guard let value = data[field] as? String else { return false }
                return values.contains(value)
            }
        }
        return query.matchAny ? results.contains(true) : !results.contains(false)
    }

    private func dateValue(of value: Any?) -> Date? {
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        return value as? Date
    }
}

func epoch(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

// MARK: - Fixtures

func makeInventoryItem(_ id: String, updatedAt: TimeInterval? = nil, lastSold: TimeInterval? = nil) -> InventoryItem {
    InventoryItem(id: id, name: id, lastSoldDate: lastSold.map(epoch), updatedAt: updatedAt.map(epoch))
}

func customerDocument(_ name: String, updatedAt: TimeInterval, lastPurchase: TimeInterval) -> [String: Any] {
    [
        "name": name, "phone": name, "totalSales": 1, "totalAmountSpent": 1.0,
        "createdAt": Timestamp(date: epoch(1)),
        "updatedAt": Timestamp(date: epoch(updatedAt)),
        "lastPurchaseDate": Timestamp(date: epoch(lastPurchase))
    ]
}

func makeTransaction(_ id: String, updatedAt: TimeInterval = 100) -> CashflowTransaction {
    CashflowTransaction(id: id, timestamp: epoch(1), particulars: "p", amount: 5, transactionType: .credit,
                        paymentMode: .cash, category: .salesRevenue, fromAccountId: "a", toAccountId: "b",
                        updatedAt: epoch(updatedAt), timestampInMs: 1, updatedAtInMs: 1)
}

func makeOrganization(_ id: String, updatedAt: TimeInterval = 100) -> Organization {
    Organization(id: id, name: id, status: "active", createdAt: epoch(1), minVersion: "1.0",
                 currentTheme: "light", accentColor: "#000000", accounts: [], updatedAt: epoch(updatedAt),
                 establishedAtInMs: 1)
}

func makeSummary(_ seconds: TimeInterval = 86_400 * 10) -> DailyCashflowSummary {
    DailyCashflowSummary(date: epoch(seconds), openingBalances: [], closingBalances: [], updatedAt: 1, locked: false)
}

// MARK: - Services

struct InventoryItemServiceTests {
    @Test func fetchesAllAndSkipsUndecodable() async throws {
        let store = MockFirestoreStore()
        try store.put(makeInventoryItem("1"), at: "organizations/o/inventory/1")
        store.documents["organizations/o/inventory/bad"] = ["currentStock": "not a number"]
        let items = try await InventoryItemService(store: store).getInventoryItems(for: "o")
        #expect(items.map(\.id).contains("1"))
    }

    @Test func deltaMatchesEitherUpdatedAtOrLastSold() async throws {
        let store = MockFirestoreStore()
        try store.put(makeInventoryItem("old", updatedAt: 10, lastSold: 10), at: "organizations/o/inventory/old")
        try store.put(makeInventoryItem("edited", updatedAt: 200, lastSold: 10), at: "organizations/o/inventory/edited")
        try store.put(makeInventoryItem("sold", updatedAt: 10, lastSold: 300), at: "organizations/o/inventory/sold")
        let ids = try await InventoryItemService(store: store).getInventoryItems(since: epoch(100), for: "o").map(\.id)
        #expect(Set(ids) == ["edited", "sold"])
    }
}

struct CustomerServiceTests {
    @Test func fetchesAll() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/o/customers/A"] = customerDocument("A", updatedAt: 1, lastPurchase: 1)
        #expect(try await CustomerService(store: store).getCustomers(for: "o").count == 1)
    }

    @Test func deltaMatchesEitherDateField() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/o/customers/old"] = customerDocument("old", updatedAt: 10, lastPurchase: 10)
        store.documents["organizations/o/customers/edited"] = customerDocument("edited", updatedAt: 200, lastPurchase: 10)
        store.documents["organizations/o/customers/bought"] = customerDocument("bought", updatedAt: 10, lastPurchase: 300)
        let names = try await CustomerService(store: store).getCustomers(since: epoch(100), for: "o").map(\.name)
        #expect(Set(names) == ["edited", "bought"])
    }
}

struct SaleServiceTests {
    @Test func fetchesAllAndSkipsUndecodable() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/o/sales/1"] = ["staffId": "s", "customerName": "C"]
        store.documents["organizations/o/sales/2"] = ["staffId": "s", "timestamp": Timestamp(date: epoch(500))]
        #expect(try await SaleService(store: store).getSales(for: "o").count == 2)
    }

    @Test func deltaFiltersOnTimestamp() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/o/sales/old"] = ["timestamp": Timestamp(date: epoch(10))]
        store.documents["organizations/o/sales/new"] = ["timestamp": Timestamp(date: epoch(500))]
        let sales = try await SaleService(store: store).getSales(since: epoch(100), for: "o")
        #expect(sales.count == 1)
    }
}

struct OrganizationServiceTests {
    @Test func getOrganizationReturnsDocument() async throws {
        let store = MockFirestoreStore()
        try store.put(makeOrganization("o"), at: "organizations/o")
        #expect(try await OrganizationService(store: store).getOrganization(for: "o").id == "o")
    }

    @Test func getOrganizationThrowsWhenMissing() async {
        let service = OrganizationService(store: MockFirestoreStore())
        await #expect(throws: NSError.self) { try await service.getOrganization(for: "nope") }
    }

    @Test func deltaFiltersByAssignedIdsAndDate() async throws {
        let store = MockFirestoreStore()
        try store.put(makeOrganization("a", updatedAt: 500), at: "organizations/a")
        try store.put(makeOrganization("b", updatedAt: 10), at: "organizations/b")
        try store.put(makeOrganization("c", updatedAt: 500), at: "organizations/c")
        let orgs = try await OrganizationService(store: store).getOrganizations(since: epoch(100), assignedIds: ["a", "b"])
        #expect(orgs.map(\.id) == ["a"])
    }

    @Test func deltaWithNoAssignedIdsReturnsEmpty() async throws {
        let orgs = try await OrganizationService(store: MockFirestoreStore()).getOrganizations(since: epoch(0), assignedIds: [])
        #expect(orgs.isEmpty)
    }
}

struct CashflowTransactionServiceTests {
    @Test func fetchesAllAndDelta() async throws {
        let store = MockFirestoreStore()
        try store.put(makeTransaction("old", updatedAt: 10), at: "organizations/o/cashflow/old")
        try store.put(makeTransaction("new", updatedAt: 500), at: "organizations/o/cashflow/new")
        let service = CashflowTransactionService(store: store)
        #expect(try await service.getCashflowTransactions(for: "o").count == 2)
        #expect(try await service.getCashflowTransactions(since: epoch(100), for: "o").map(\.id) == ["new"])
    }

    @Test func addWritesOnceAndSkipsDuplicates() async throws {
        let store = MockFirestoreStore()
        let service = CashflowTransactionService(store: store)
        try await service.addCashflowTransaction(makeTransaction("1"), for: "o")
        try await service.addCashflowTransaction(makeTransaction("1"), for: "o")
        #expect(store.writes.count == 1)
        #expect(store.writes.first?.path == "organizations/o/cashflow/1")
        #expect(store.writes.first?.merge == false)
    }

    @Test func updateMergesWithFreshTimestamp() async throws {
        let store = MockFirestoreStore()
        try await CashflowTransactionService(store: store).updateCashflowTransaction(makeTransaction("1", updatedAt: 10), for: "o")
        #expect(store.writes.first?.merge == true)
        let written = try Firestore.Decoder().decode(CashflowTransaction.self, from: store.writes[0].data)
        #expect(written.updatedAt > epoch(1_000))
    }

    @Test func deleteSoftDeletes() async throws {
        let store = MockFirestoreStore()
        try await CashflowTransactionService(store: store).deleteCashflowTransaction(id: "1", for: "o")
        #expect(store.updates.first?.path == "organizations/o/cashflow/1")
        #expect(store.updates.first?.fields["isDeleted"] as? Bool == true)
    }
}

struct DailyCashflowSummaryServiceTests {
    @Test func getByDateReturnsDocument() async throws {
        let store = MockFirestoreStore()
        let summary = makeSummary()
        try store.put(summary, at: "organizations/o/dailyCashflowSummaries/\(summary.id)")
        let fetched = try await DailyCashflowSummaryService(store: store).getDailyCashflowSummary(orgId: "o", date: summary.id)
        #expect(fetched.id == summary.id)
    }

    @Test func getByDateThrowsWhenMissing() async {
        let service = DailyCashflowSummaryService(store: MockFirestoreStore())
        await #expect(throws: NSError.self) { try await service.getDailyCashflowSummary(orgId: "o", date: "01-01-2026") }
    }

    @Test func fetchesAllAndDelta() async throws {
        let store = MockFirestoreStore()
        try store.put(makeSummary(86_400 * 10), at: "organizations/o/dailyCashflowSummaries/a")
        let service = DailyCashflowSummaryService(store: store)
        #expect(try await service.getDailyCashflowSummaries(for: "o").count == 1)
        _ = try await service.getDailyCashflowSummaries(since: epoch(0), for: "o")
    }

    @Test func addSkipsExistingAndUpdateMerges() async throws {
        let store = MockFirestoreStore()
        let service = DailyCashflowSummaryService(store: store)
        let summary = makeSummary()
        try await service.addDailyCashflowSummary(summary, for: "o")
        try await service.addDailyCashflowSummary(summary, for: "o")
        try await service.updateDailyCashflowSummary(summary, for: "o")
        #expect(store.writes.map(\.merge) == [false, true])
    }
}
