//
//  SaleAndCashflowRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
import ApoorvaServices
@testable import ApoorvaRepository

// MARK: - Sale mocks

final class MockSaleStorage: SaleStorageProtocol, @unchecked Sendable {
    var sales: [Sale] = []
    var calls: [String] = []
    var lastUpdated: Sale?

    func getSales() async throws -> [Sale] { calls.append("get"); return sales }
    func saveSales(sales: [Sale]) async throws { calls.append("saveMany"); self.sales = sales }
    func saveSale(sale: Sale) async throws { calls.append("save") }
    func getSale(id: String) async throws -> Sale? { sales.first { $0.id == id } }
    func updateSale(sale: Sale) async throws { calls.append("update"); lastUpdated = sale }
    func deleteSale(id: String) async throws { calls.append("delete") }
    func markAsDeleted(id: String) async throws { calls.append("markDeleted") }
}

final class MockSaleService: SaleServiceProtocol, @unchecked Sendable {
    var result: [Sale] = []
    var calls: [String] = []

    func getSales(for orgId: String) async throws -> [Sale] { calls.append("all"); return result }
    func getSales(since lastSync: Date, for orgId: String) async throws -> [Sale] { calls.append("since"); return result }
    func addSale(_ sale: Sale, for orgId: String) async throws { calls.append("add") }
    func updateSaleStatus(saleId: String, status: String, reason: String, by staffId: String, at date: Date, for orgId: String) async throws {
        calls.append("status:\(status)")
    }
    func updateSale(_ sale: Sale, for orgId: String) async throws { calls.append("updateRemote") }
}

final class MockCustomerServiceForSale: CustomerServiceProtocol, @unchecked Sendable {
    var calls: [String] = []

    func getCustomers(for orgId: String) async throws -> [Customer] { [] }
    func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer] { [] }
    func upsertCustomerAfterSale(phone: String, name: String, saleAmount: Double, saleDate: Date, for orgId: String) async throws {
        calls.append("upsert")
    }
}

final class MockHeldBillRepositoryForSale: HeldBillRepositoryProtocol, @unchecked Sendable {
    var calls: [String] = []

    func getHeldBills() async throws -> [HeldBill] { [] }
    func saveHeldBill(_ heldBill: HeldBill) async throws { calls.append("save") }
    func updateHeldBill(_ heldBill: HeldBill) async throws { calls.append("update") }
    func deleteHeldBill(id: String) async throws { calls.append("delete") }
    func markAsDeleted(id: String) async throws { calls.append("markDeleted") }
    func sync(force: Bool) async throws { calls.append("sync") }
}

func makeSale(updatedAt: Date? = nil) -> Sale {
    Sale(id: UUID().uuidString, staffId: "s", customerPhone: "1", customerName: "C", items: [],
         subtotal: 10, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0,
         netPayable: 10, payments: [:], timestamp: Date(timeIntervalSince1970: 1),
         source: "pos", status: "done", whatsappStatus: "none", updatedAt: updatedAt)
}

@MainActor func makeUserRepository(user: AppUser?) -> UserRepository {
    let userService = MockUserService()
    userService.user = user
    return UserRepository(userDefaults: MockUserDefaultsStorage(),
                          authService: StubAuthService(),
                          userService: userService)
}

@MainActor
struct SaleRepositoryTests {
    private func makeSUT(user: AppUser?) throws -> (SaleRepository, MockSaleStorage, MockSaleService, SyncStorage, MockCustomerServiceForSale, MockHeldBillRepositoryForSale) {
        let storage = MockSaleStorage()
        let service = MockSaleService()
        let customerService = MockCustomerServiceForSale()
        let heldBillRepository = MockHeldBillRepositoryForSale()
        let sync = SyncStorage(db: try SkipSqlDatabase(filepath: ":memory:"))
        return (SaleRepository(storage: storage, service: service,
                               customerService: customerService, heldBillRepository: heldBillRepository,
                               userRepository: makeUserRepository(user: user), syncStorage: sync),
                storage, service, sync, customerService, heldBillRepository)
    }

    @Test func crudDelegatesToStorage() async throws {
        let (sut, storage, _, _, _, _) = try makeSUT(user: nil)
        let sale = makeSale()
        try await sut.saveSale(sale: sale)
        try await sut.updateSale(sale)
        try await sut.deleteSale(id: sale.id)
        try await sut.markAsDeleted(id: sale.id)
        _ = try await sut.getSales()
        #expect(storage.calls == ["save", "update", "delete", "markDeleted", "get"])
    }

    @Test func syncSkipsWithoutOrganization() async throws {
        let (sut, _, service, _, _, _) = try makeSUT(user: try makeUser())
        try await sut.sync(force: false)
        #expect(service.calls.isEmpty)
    }

    @Test func firstSyncStoresTimestamp() async throws {
        let (sut, storage, service, sync, _, _) = try makeSUT(user: try makeUser(orgId: "o"))
        service.result = [makeSale(updatedAt: Date(timeIntervalSince1970: 400))]
        try await sut.sync(force: false)
        #expect(service.calls == ["all"])
        #expect(storage.sales.count == 1)
        #expect(try await sync.getLastSyncTimestamp(for: Sale.table.name) == 400)
    }

    @Test func incrementalAndForcedSync() async throws {
        let (sut, _, service, sync, _, _) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sync.updateSyncTimestamp(for: Sale.table.name, timestamp: 5)
        try await sut.sync(force: false)
        try await sut.sync(force: true)
        #expect(service.calls == ["since", "all"])
    }

    @Test func confirmSaleWritesCustomerAndClearsHeldBill() async throws {
        let (sut, storage, service, _, customerService, heldBillRepository) = try makeSUT(user: try makeUser(orgId: "o"))
        let sale = makeSale()
        try await sut.confirmSale(sale, heldBillId: "draft-1")
        #expect(storage.calls.contains("save"))
        #expect(service.calls.contains("add"))
        #expect(customerService.calls.contains("upsert"))
        #expect(heldBillRepository.calls.contains("delete"))
    }

    @Test func syncCursorTracksNewestOfTimestampAndUpdatedAt() async throws {
        let (sut, _, service, sync, _, _) = try makeSUT(user: try makeUser(orgId: "o"))
        let newSale = Sale(id: "n", staffId: "s", customerPhone: "1", customerName: "C", items: [], subtotal: 1,
                           overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 1,
                           payments: [:], timestamp: Date(timeIntervalSince1970: 900), source: "pos",
                           status: "done", whatsappStatus: "none", updatedAt: Date(timeIntervalSince1970: 50))
        service.result = [makeSale(updatedAt: Date(timeIntervalSince1970: 400)), newSale]
        try await sut.sync(force: true)
        #expect(try await sync.getLastSyncTimestamp(for: Sale.table.name) == 900)
    }

    @Test func cancelSaleMarksCancelledLocallyAndRemotely() async throws {
        let (sut, storage, service, _, _, _) = try makeSUT(user: try makeUser(orgId: "o"))
        let sale = makeSale()
        storage.sales = [sale]
        let cancelled = try await sut.cancelSale(id: sale.id, reason: "Wrong items", by: "u1")
        #expect(cancelled?.isCancelled == true)
        #expect(storage.lastUpdated?.cancelReason == "Wrong items")
        #expect(service.calls.contains("status:Cancelled"))
    }

    @Test func cancelSaleIsNoOpWhenAlreadyCancelled() async throws {
        let (sut, storage, service, _, _, _) = try makeSUT(user: try makeUser(orgId: "o"))
        var sale = makeSale()
        sale.status = "Cancelled"
        storage.sales = [sale]
        #expect(try await sut.cancelSale(id: sale.id, reason: "again", by: "u1") == nil)
        #expect(service.calls.isEmpty)
    }

    @Test func confirmSaleWithoutHeldBillLeavesHeldBillsUntouched() async throws {
        let (sut, _, _, _, _, heldBillRepository) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sut.confirmSale(makeSale(), heldBillId: nil)
        #expect(heldBillRepository.calls.isEmpty)
    }
}

// MARK: - Cashflow mocks

final class MockCashflowStorage: CashflowTransactionStorageProtocol, @unchecked Sendable {
    var transactions: [CashflowTransaction] = []
    var calls: [String] = []

    func getCashflowTransactions() async throws -> [CashflowTransaction] { calls.append("get"); return transactions }
    func saveCashflowTransactions(transactions: [CashflowTransaction]) async throws { calls.append("saveMany"); self.transactions = transactions }
    func saveCashflowTransaction(transaction: CashflowTransaction) async throws { calls.append("save") }
    func getCashflowTransaction(id: String) async throws -> CashflowTransaction? { nil }
    func updateCashflowTransaction(transaction: CashflowTransaction) async throws { calls.append("update") }
    func deleteCashflowTransaction(id: String) async throws { calls.append("delete") }
    func markAsDeleted(id: String) async throws { calls.append("markDeleted") }
}

final class MockCashflowService: CashflowTransactionServiceProtocol, @unchecked Sendable {
    var result: [CashflowTransaction] = []
    var calls: [String] = []

    func getCashflowTransactions(for orgId: String) async throws -> [CashflowTransaction] { calls.append("all"); return result }
    func getCashflowTransactions(since lastSync: Date, for orgId: String) async throws -> [CashflowTransaction] { calls.append("since"); return result }
    func addCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws { calls.append("add") }
    func updateCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws { calls.append("updateRemote") }
}

func makeTransaction(updatedAt: Date = Date(timeIntervalSince1970: 100)) -> CashflowTransaction {
    CashflowTransaction(timestamp: Date(timeIntervalSince1970: 1), particulars: "p", amount: 5,
                        transactionType: .credit, paymentMode: .cash, category: .salesRevenue,
                        fromAccountId: "a", toAccountId: "b", updatedAt: updatedAt,
                        timestampInMs: 1, updatedAtInMs: 1)
}

@MainActor
struct CashflowTransactionRepositoryTests {
    private func makeSUT(user: AppUser?) throws -> (CashflowTransactionRepository, MockCashflowStorage, MockCashflowService, SyncStorage) {
        let storage = MockCashflowStorage()
        let service = MockCashflowService()
        let sync = SyncStorage(db: try SkipSqlDatabase(filepath: ":memory:"))
        return (CashflowTransactionRepository(storage: storage, service: service,
                                               userRepository: makeUserRepository(user: user), syncStorage: sync),
                storage, service, sync)
    }

    @Test func localOperationsDelegateToStorage() async throws {
        let (sut, storage, _, _) = try makeSUT(user: nil)
        _ = try await sut.getCashflowTransactions()
        try await sut.deleteCashflowTransaction(id: "1")
        try await sut.markAsDeleted(id: "1")
        #expect(storage.calls == ["get", "delete", "markDeleted"])
    }

    @Test func saveAndUpdateWriteRemoteThenSync() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser(orgId: "o"))
        service.result = [makeTransaction()]
        try await sut.saveCashflowTransaction(transaction: makeTransaction())
        try await sut.updateCashflowTransaction(makeTransaction())
        #expect(service.calls.contains("add"))
        #expect(service.calls.contains("updateRemote"))
        #expect(storage.calls.contains("saveMany"))
    }

    @Test func saveAndUpdateDoNothingWithoutOrganization() async throws {
        let (sut, _, service, _) = try makeSUT(user: try makeUser())
        try await sut.saveCashflowTransaction(transaction: makeTransaction())
        try await sut.updateCashflowTransaction(makeTransaction())
        #expect(service.calls.isEmpty)
    }

    @Test func syncStoresLatestTimestamp() async throws {
        let (sut, _, service, sync) = try makeSUT(user: try makeUser(orgId: "o"))
        service.result = [makeTransaction(updatedAt: Date(timeIntervalSince1970: 100)),
                          makeTransaction(updatedAt: Date(timeIntervalSince1970: 900))]
        try await sut.sync(force: false)
        #expect(try await sync.getLastSyncTimestamp(for: CashflowTransaction.table.name) == 900)
    }

    @Test func incrementalAndForcedSync() async throws {
        let (sut, _, service, sync) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sync.updateSyncTimestamp(for: CashflowTransaction.table.name, timestamp: 5)
        try await sut.sync(force: false)
        try await sut.sync(force: true)
        #expect(service.calls == ["since", "all"])
    }
}
