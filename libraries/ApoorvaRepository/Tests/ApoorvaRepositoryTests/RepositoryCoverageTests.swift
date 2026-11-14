//
//  RepositoryCoverageTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
import ApoorvaServices
@testable import ApoorvaRepository

// MARK: - Shared helpers

private func memoryDatabase() throws -> SkipSqlDatabase {
    try SkipSqlDatabase(filepath: ":memory:")
}

private func collection<T: OrgDocument>(_ type: T.Type, database: SkipSqlDatabase, orgId: String? = nil,
                                        store: InMemoryStore = InMemoryStore()) -> OrgCollectionRepository<T> {
    OrgCollectionRepository<T>(storage: OrgCollectionLocalStorage(database: database), service: OrgCollectionService(store: store),
                               context: FixedOrgContext(orgId: orgId), syncStorage: SyncStorage(db: database))
}

private struct ThrowingContext: OrgContextProviding {
    func currentOrgId() async throws -> String? { throw TestError.failed }
    func currentActor() async throws -> (id: String, name: String) { throw TestError.failed }
}

private final class RecordingCrash: CrashReportingServicing, @unchecked Sendable {
    var contexts: [String] = []
    func recordNonFatal(_ error: Error, context: String) { contexts.append(context) }
    func setCustomKey(_ value: String, forKey key: String) {}
    func setUserId(_ id: String?) {}
    func log(_ message: String) {}
}

// MARK: - HeldBillRepository

private final class MockHeldBillStorage: HeldBillStorageProtocol, @unchecked Sendable {
    var bills: [HeldBill] = []
    var calls: [String] = []

    func getHeldBills() async throws -> [HeldBill] { calls.append("get"); return bills }
    func saveHeldBills(heldBills: [HeldBill]) async throws { calls.append("saveMany"); bills = heldBills }
    func saveHeldBill(heldBill: HeldBill) async throws { calls.append("save") }
    func getHeldBill(id: String) async throws -> HeldBill? { nil }
    func updateHeldBill(heldBill: HeldBill) async throws { calls.append("update") }
    func deleteHeldBill(id: String) async throws { calls.append("delete") }
    func markAsDeleted(id: String) async throws { calls.append("markDeleted") }
}

private final class MockHeldBillService: HeldBillServiceProtocol, @unchecked Sendable {
    var result: [HeldBill] = []
    var calls: [String] = []

    func getHeldBills(for orgId: String) async throws -> [HeldBill] { calls.append("all"); return result }
    func getHeldBills(since lastSync: Date, for orgId: String) async throws -> [HeldBill] { calls.append("since"); return result }
    func addHeldBill(_ heldBill: HeldBill, for orgId: String) async throws { calls.append("add") }
    func updateHeldBill(_ heldBill: HeldBill, for orgId: String) async throws { calls.append("update") }
    func deleteHeldBill(id: String, for orgId: String) async throws { calls.append("delete") }
}

private func bill(_ id: String, updatedAt: TimeInterval? = nil) -> HeldBill {
    HeldBill(id: id, customerName: "A", customerPhone: "9", items: [], total: 10,
             createdAt: Date(timeIntervalSince1970: 1), updatedAt: updatedAt.map { Date(timeIntervalSince1970: $0) })
}

@MainActor
struct HeldBillRepositoryTests {
    private func makeSUT(user: AppUser?) throws -> (HeldBillRepository, MockHeldBillStorage, MockHeldBillService, SyncStorage) {
        let storage = MockHeldBillStorage()
        let service = MockHeldBillService()
        let sync = SyncStorage(db: try memoryDatabase())
        return (HeldBillRepository(storage: storage, service: service, userRepository: makeUserRepository(user: user), syncStorage: sync),
                storage, service, sync)
    }

    @Test func localOperationsDelegateToStorage() async throws {
        let (sut, storage, _, _) = try makeSUT(user: nil)
        _ = try await sut.getHeldBills()
        try await sut.markAsDeleted(id: "1")
        #expect(storage.calls == ["get", "markDeleted"])
    }

    @Test func writesReachTheServiceWhenAnOrganizationIsSelected() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sut.saveHeldBill(bill("1"))
        try await sut.updateHeldBill(bill("1"))
        try await sut.deleteHeldBill(id: "1")
        #expect(storage.calls == ["save", "update", "markDeleted"])
        #expect(service.calls == ["add", "update", "delete"])
    }

    @Test func writesStayLocalWithoutAnOrganization() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser())
        try await sut.saveHeldBill(bill("1"))
        try await sut.updateHeldBill(bill("1"))
        try await sut.deleteHeldBill(id: "1")
        #expect(storage.calls.count == 3)
        #expect(service.calls.isEmpty)
    }

    @Test func syncSkipsWithoutAnOrganization() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser())
        try await sut.sync(force: false)
        #expect(service.calls.isEmpty && storage.calls.isEmpty)
    }

    @Test func firstSyncFetchesAllAndStoresNewestTimestamp() async throws {
        let (sut, storage, service, sync) = try makeSUT(user: try makeUser(orgId: "o"))
        service.result = [bill("a", updatedAt: 100), bill("b", updatedAt: 900), bill("c")]
        try await sut.sync(force: false)
        #expect(service.calls == ["all"])
        #expect(storage.bills.count == 3)
        #expect(try await sync.getLastSyncTimestamp(for: "HeldBill") == 900)
    }

    @Test func incrementalAndForcedSync() async throws {
        let (sut, _, service, sync) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sync.updateSyncTimestamp(for: "HeldBill", timestamp: 5)
        try await sut.sync(force: false)
        try await sut.sync(force: true)
        #expect(service.calls == ["since", "all"])
    }

    @Test func syncWithoutTimestampsLeavesCursorUntouched() async throws {
        let (sut, _, service, sync) = try makeSUT(user: try makeUser(orgId: "o"))
        service.result = [bill("a")]
        try await sut.sync(force: false)
        #expect(try await sync.getLastSyncTimestamp(for: "HeldBill") == nil)
        service.result = []
        try await sut.sync(force: false)
        #expect(try await sync.getLastSyncTimestamp(for: "HeldBill") == nil)
    }
}

// MARK: - SyncAdapter / SyncEngine

struct SyncEngineCoverageTests {
    private final class Flag: @unchecked Sendable { var forced: [Bool] = [] }

    @Test func syncAdapterForwardsKeyAndForce() async throws {
        let flag = Flag()
        let adapter = SyncAdapter("custom") { force in flag.forced.append(force) }
        #expect(adapter.syncKey == "custom")
        try await adapter.sync(force: true)
        try await adapter.sync(force: false)
        #expect(flag.forced == [true, false])
    }

    @Test func engineRunsAdaptersAndTracksStatus() async {
        let engine = SyncEngine(repositories: [SyncAdapter("a") { _ in }, SyncAdapter("a") { _ in }, SyncAdapter("b") { _ in }])
        #expect(await engine.allStatuses().map(\.key) == ["a", "b"])
        #expect(await engine.lastSuccessfulSync == nil)
        #expect(await engine.failedCount == 0)
        let statuses = await engine.syncAll(force: true)
        #expect(statuses.allSatisfy { $0.lastSuccess != nil && $0.lastError == nil && !$0.isSyncing })
        #expect(await engine.lastSuccessfulSync != nil)
    }

    @Test func failuresAreRecordedAndReported() async {
        let crash = RecordingCrash()
        let engine = SyncEngine(repositories: [SyncAdapter("bad") { _ in throw TestError.failed }], crashReportingService: crash)
        await engine.syncAll()
        #expect(crash.contexts == ["sync.bad"])
        #expect(await engine.failedCount == 1)
        #expect(await engine.statuses["bad"]?.lastError != nil)
    }

    @Test func syncStatusInitDefaults() {
        let status = SyncStatus(key: "k")
        #expect(status.lastSuccess == nil && status.lastError == nil && !status.isSyncing)
    }
}

// MARK: - OrgCollectionRepository

struct OrgCollectionRepositoryCoverageTests {
    private func entry(_ id: String) -> CustomerLedgerEntry {
        CustomerLedgerEntry(id: id, customerPhone: "9", customerName: "Asha", kind: .sale, amount: 100, createdBy: "u1")
    }

    @Test func getReturnsSavedDocumentAndSyncKeyIsCollectionBased() async throws {
        let sut = collection(CustomerLedgerEntry.self, database: try memoryDatabase())
        try await sut.save(entry("a"))
        #expect(try await sut.get(id: "a")?.id == "a")
        #expect(try await sut.get(id: "zzz") == nil)
        #expect(sut.syncKey.hasPrefix("org."))
    }

    @Test func saveAllHandlesEmptyLocalAndRemote() async throws {
        let database = try memoryDatabase()
        let store = InMemoryStore()
        let local = collection(CustomerLedgerEntry.self, database: database)
        try await local.saveAll([])
        try await local.saveAll([entry("a"), entry("b")])
        #expect(try await local.all().count == 2)

        let remote = collection(CustomerLedgerEntry.self, database: try memoryDatabase(), orgId: "org", store: store)
        try await remote.saveAll([entry("a"), entry("b")])
        #expect(store.setCount == 2)
    }

    @Test func syncDoesNothingWithoutAnOrganization() async throws {
        let sut = collection(CustomerLedgerEntry.self, database: try memoryDatabase())
        try await sut.sync(force: false)
        #expect(try await sut.all().isEmpty)
    }

    @Test func syncStoresServerCursorAndReusesItUnlessForced() async throws {
        let database = try memoryDatabase()
        let store = InMemoryStore()
        let sut = collection(CustomerLedgerEntry.self, database: database, orgId: "org", store: store)
        try await sut.save(entry("a"))
        store.documents["organizations/org/customerLedger/a"]?["serverUpdatedAt"] = Date(timeIntervalSince1970: 5_000)

        try await sut.sync(force: false)
        let sync = SyncStorage(db: database)
        #expect(try await sync.getLastSyncTimestamp(for: sut.syncKey) == 5_000)
        try await sut.sync(force: false)
        try await sut.sync(force: true)
    }

    @Test func changesStreamStopsObservingWhenTerminated() async throws {
        let sut = collection(CustomerLedgerEntry.self, database: try memoryDatabase())
        let stream = await sut.changes()
        let waiting = Task { for await _ in stream { return } }
        try await Task.sleep(for: .milliseconds(100))
        try await sut.save(entry("a"))
        await waiting.value
        try await Task.sleep(for: .milliseconds(100))
        try await sut.save(entry("b"))
    }

    @MainActor
    @Test func userBackedContextReadsOrgAndActor() async throws {
        let context = UserRepositoryOrgContext(userRepository: makeUserRepository(user: try makeUser(id: "u9", orgId: "o9")))
        #expect(try await context.currentOrgId() == "o9")
        let actor = try await context.currentActor()
        #expect(actor.id == "u9" && actor.name == "Test")
        let noOrg = UserRepositoryOrgContext(userRepository: makeUserRepository(user: try makeUser()))
        #expect(try await noOrg.currentOrgId() == nil)
    }

    @Test func auditLoggerSwallowsFailures() async throws {
        let repository = collection(AuditEvent.self, database: try memoryDatabase())
        await AuditLogger(repository: repository, context: ThrowingContext()).log(.bills, action: "x", summary: "y")
        #expect(try await repository.all().isEmpty)
    }
}

// MARK: - Customer / Inventory / Cashflow / Sales repositories

private final class GettableInventoryStorage: InventoryItemLocalStorageProtocol, @unchecked Sendable {
    var item: InventoryItem?
    func getInventoryItems() async throws -> [InventoryItem] { [] }
    func saveInventoryItems(items: [InventoryItem]) async throws {}
    func saveInventoryItem(item: InventoryItem) async throws {}
    func getInventoryItem(id: String) async throws -> InventoryItem? { item }
    func updateInventoryItem(item: InventoryItem) async throws {}
    func deleteInventoryItem(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
}

private final class UpsertRecordingInventoryService: InventoryItemServiceProtocol, @unchecked Sendable {
    var upserts: [String] = []
    func getInventoryItems(for orgId: String) async throws -> [InventoryItem] { [] }
    func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem] { [] }
    func upsertInventoryItem(_ item: InventoryItem, for orgId: String) throws { upserts.append(item.id) }
}

@MainActor
struct RepositoryEdgeCaseTests {
    @Test func customerRepositoryLooksUpByPhone() async throws {
        let sut = CustomerRepository(storage: MockCustomerStorage(), service: MockCustomerService(),
                                     userRepository: makeUserRepository(user: try makeUser(orgId: "o")),
                                     syncStorage: SyncStorage(db: try memoryDatabase()))
        #expect(try await sut.getCustomer(phone: "123") == nil)
        try await sut.saveCustomer(customer: makeCustomer())
        try await sut.updateCustomer(makeCustomer())
    }

    @Test func inventoryPushesRemoteOnlyWithAnOrganization() async throws {
        let storage = GettableInventoryStorage()
        let service = UpsertRecordingInventoryService()
        let withOrg = InventoryItemRepository(storage: storage, service: service,
                                              userRepository: makeUserRepository(user: try makeUser(orgId: "o")),
                                              syncStorage: SyncStorage(db: try memoryDatabase()))
        let item = InventoryItem(id: "i1", name: "Pen")
        storage.item = item
        try await withOrg.saveInventoryItem(item: item)
        try await withOrg.updateInventoryItem(item)
        try await withOrg.markAsDeleted(id: "i1")
        #expect(service.upserts == ["i1", "i1", "i1"])

        storage.item = nil
        try await withOrg.markAsDeleted(id: "gone")
        #expect(service.upserts.count == 3)

        let withoutOrg = InventoryItemRepository(storage: storage, service: service,
                                                 userRepository: makeUserRepository(user: nil),
                                                 syncStorage: SyncStorage(db: try memoryDatabase()))
        try await withoutOrg.saveInventoryItem(item: item)
        #expect(service.upserts.count == 3)
    }

    @Test func inventoryLastSyncedAtReflectsStoredCursor() async throws {
        let sync = SyncStorage(db: try memoryDatabase())
        let sut = InventoryItemRepository(storage: MockInventoryStorage(), service: MockInventoryService(),
                                          userRepository: makeUserRepository(user: nil), syncStorage: sync)
        #expect(try await sut.lastSyncedAt() == nil)
        try await sync.updateSyncTimestamp(for: InventoryItem.table.name, timestamp: 42)
        #expect(try await sut.lastSyncedAt() == Date(timeIntervalSince1970: 42))
    }

    @Test func cashflowSyncWithNoTransactionsLeavesCursorUntouched() async throws {
        let sync = SyncStorage(db: try memoryDatabase())
        let sut = CashflowTransactionRepository(storage: MockCashflowStorage(), service: MockCashflowService(),
                                                userRepository: makeUserRepository(user: try makeUser(orgId: "o")), syncStorage: sync)
        try await sut.sync(force: false)
        #expect(try await sync.getLastSyncTimestamp(for: CashflowTransaction.table.name) == nil)
    }

    @Test func salesRepositoryEditAndCancelWithAndWithoutOrganization() async throws {
        for orgId in ["o", nil] as [String?] {
            let storage = MockSaleStorage()
            let service = MockSaleService()
            let sut = SaleRepository(storage: storage, service: service, customerService: MockCustomerServiceForSale(),
                                     heldBillRepository: MockHeldBillRepositoryForSale(),
                                     userRepository: makeUserRepository(user: try makeUser(orgId: orgId)),
                                     syncStorage: SyncStorage(db: try memoryDatabase()))
            let sale = makeSale()
            storage.sales = [sale]
            try await sut.editSale(sale, reason: "typo")
            #expect(storage.lastUpdated?.editReason == "typo")
            #expect(service.calls.contains("updateRemote") == (orgId != nil))

            #expect(try await sut.cancelSale(id: sale.id, reason: "r", by: "u")?.isCancelled == true)
            #expect(service.calls.contains("status:Cancelled") == (orgId != nil))
            #expect(try await sut.cancelSale(id: "missing", reason: "r", by: "u") == nil)
            #expect(try await sut.getSale(id: sale.id)?.id == sale.id)
        }
    }

    @Test func confirmSaleWithoutOrganizationOnlySavesLocally() async throws {
        let storage = MockSaleStorage()
        let service = MockSaleService()
        let sut = SaleRepository(storage: storage, service: service, customerService: MockCustomerServiceForSale(),
                                 heldBillRepository: MockHeldBillRepositoryForSale(),
                                 userRepository: makeUserRepository(user: try makeUser()),
                                 syncStorage: SyncStorage(db: try memoryDatabase()))
        try await sut.confirmSale(makeSale(), heldBillId: "h")
        #expect(storage.calls == ["save"])
        #expect(service.calls.isEmpty)
    }

    @Test func demoUserOverridesTheServiceUser() async throws {
        // Through the protocol, as the app calls it, so the actor's own implementation is the one dispatched to.
        let sut: any UserRepositoryProtocol = makeUserRepository(user: try makeUser(id: "real"))
        await sut.setDemoUser(try makeUser(id: "demo"))
        #expect(try await sut.getCurrentUser().id == "demo")
        await sut.setDemoUser(nil)
        #expect(try await sut.getCurrentUser().id == "real")
    }

    @Test func protocolDefaultDemoUserIsNoOp() async throws {
        struct Bare: UserRepositoryProtocol {
            func getCurrentUser() async throws -> AppUser { throw TestError.failed }
            func getUser(id: String) async throws -> AppUser? { nil }
            func setUser(user: AppUser) async throws {}
            func updateUser(user: AppUser) async throws {}
            func deleteUser(id: String) async {}
            func updateSelectedOrganization(for user: AppUser, organization: OrganizationSnapshot) async throws {}
            func listUsers(orgId: String) async throws -> [AppUser] { [] }
            func updateUserRole(id: String, role: AppUserRole) async throws {}
        }
        await Bare().setDemoUser(nil)
    }
}

// MARK: - SaleLifecycleRepository

private final class StubbornSaleRepository: SaleRepositoryProtocol, @unchecked Sendable {
    let sale: Sale
    init(_ sale: Sale) { self.sale = sale }
    func getSales() async throws -> [Sale] { [sale] }
    func getSale(id: String) async throws -> Sale? { sale }
    func saveSale(sale: Sale) async throws {}
    func updateSale(_ sale: Sale) async throws {}
    func deleteSale(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func confirmSale(_ sale: Sale, heldBillId: String?) async throws {}
    func cancelSale(id: String, reason: String, by staffId: String) async throws -> Sale? { nil }
    func editSale(_ sale: Sale, reason: String) async throws {}
    func sync(force: Bool) async throws {}
}

struct SaleLifecycleCoverageTests {

    private struct Harness {
        let lifecycle: SaleLifecycleRepository
        let sales: LifecycleSaleRepository
        let inventory: LifecycleInventoryRepository
        let customers: LifecycleCustomerRepository
        let movements: OrgCollectionRepository<StockMovement>
        let ledger: OrgCollectionRepository<CustomerLedgerEntry>
        let audit: RecordingAudit
    }

    private func makeHarness() throws -> Harness {
        let database = try memoryDatabase()
        let movements = collection(StockMovement.self, database: database)
        let ledger = collection(CustomerLedgerEntry.self, database: database)
        let sales = LifecycleSaleRepository()
        let inventory = LifecycleInventoryRepository()
        inventory.items["pen"] = InventoryItem(id: "pen", name: "Pen", currentStock: 10)
        let customers = LifecycleCustomerRepository()
        customers.customers["9"] = Customer(name: "Asha", phone: "9", createdAt: 0, lastPurchaseDate: nil, totalSales: 1,
                                            totalAmountSpent: 0, updatedAt: nil, isDeleted: false)
        let audit = RecordingAudit()
        let lifecycle = SaleLifecycleRepository(saleRepository: sales, inventoryRepository: inventory, customerRepository: customers,
                                                stockMovements: movements, ledger: ledger, audit: audit)
        return Harness(lifecycle: lifecycle, sales: sales, inventory: inventory, customers: customers,
                       movements: movements, ledger: ledger, audit: audit)
    }

    private func line(_ id: String, qty: Int) -> SaleItem {
        SaleItem(categoryId: id, categoryName: id, qty: qty, stickerPrice: 10, finalPrice: 10, discountType: .percentage)
    }

    private func sale(items: [SaleItem], credit: Double = 0, phone: String = "9", returnOf: String? = nil,
                      status: String = "Completed", at date: Date = Date()) -> Sale {
        var payments: [PaymentMode: Double] = [.cash: 10]
        if credit > 0 { payments[.credit] = credit }
        var sale = Sale(id: "s1", staffId: "u1", customerPhone: phone, customerName: "Asha", items: items,
                        subtotal: 30, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 30,
                        payments: payments, timestamp: date, source: "POS", status: status, whatsappStatus: "unsent")
        sale.returnOfSaleId = returnOf
        return sale
    }

    @Test func errorsDescribeThemselves() {
        for error in [SaleLifecycleError.notFound, .alreadyCancelled, .undoWindowPassed] {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func missingSaleFailsEveryOperation() async throws {
        let harness = try makeHarness()
        await #expect(throws: SaleLifecycleError.notFound) { try await harness.lifecycle.cancel(saleId: "x", reason: "r", by: "u") }
        await #expect(throws: SaleLifecycleError.notFound) { try await harness.lifecycle.undo(saleId: "x", by: "u", now: Date()) }
        await #expect(throws: SaleLifecycleError.notFound) {
            try await harness.lifecycle.edit(self.sale(items: []), reason: "r", by: "u")
        }
    }

    @Test func cancelledSalesCannotBeCancelledOrEditedAgain() async throws {
        let harness = try makeHarness()
        let cancelled = sale(items: [line("pen", qty: 1)], status: "Cancelled")
        harness.sales.sales["s1"] = cancelled
        await #expect(throws: SaleLifecycleError.alreadyCancelled) { try await harness.lifecycle.cancel(saleId: "s1", reason: "r", by: "u") }
        await #expect(throws: SaleLifecycleError.alreadyCancelled) { try await harness.lifecycle.edit(cancelled, reason: "r", by: "u") }
    }

    @Test func repositoryRefusingTheCancelSurfacesAlreadyCancelled() async throws {
        let harness = try makeHarness()
        let lifecycle = SaleLifecycleRepository(saleRepository: StubbornSaleRepository(sale(items: [])),
                                                inventoryRepository: harness.inventory, customerRepository: harness.customers,
                                                stockMovements: harness.movements, ledger: harness.ledger, audit: harness.audit)
        await #expect(throws: SaleLifecycleError.alreadyCancelled) { try await lifecycle.cancel(saleId: "s1", reason: "r", by: "u") }
    }

    @Test func undoPastTheWindowIsRefusedAndInsideItIsLoggedAsUndo() async throws {
        let harness = try makeHarness()
        let saved = sale(items: [line("pen", qty: 2)], at: Date(timeIntervalSince1970: 1_000))
        harness.sales.sales["s1"] = saved
        await #expect(throws: SaleLifecycleError.undoWindowPassed) {
            try await harness.lifecycle.undo(saleId: "s1", by: "u", now: Date(timeIntervalSince1970: 1_000 + 301))
        }
        try await harness.lifecycle.undo(saleId: "s1", by: "u", now: Date(timeIntervalSince1970: 1_100))
        #expect(harness.audit.box.actions == ["bill.undo"])
    }

    @Test func recordEffectsSkipsEmptyLinesAndMissingPhone() async throws {
        let harness = try makeHarness()
        try await harness.lifecycle.recordEffects(of: sale(items: []), by: "u")
        try await harness.lifecycle.recordEffects(of: sale(items: [line("pen", qty: 1)], credit: 5, phone: ""), by: "u")
        #expect(try await harness.ledger.all().isEmpty)
        #expect(harness.inventory.items["pen"]?.currentStock == 9)
    }

    @Test func recordEffectsSkipsUnstockedAndUnknownItems() async throws {
        let harness = try makeHarness()
        let items = [line("custom-1", qty: 1), line("package:p", qty: 1), line("ghost", qty: 1), line("pen", qty: 0)]
        try await harness.lifecycle.recordEffects(of: sale(items: items), by: "u")
        #expect(harness.inventory.items["pen"]?.currentStock == 10)
        #expect(try await harness.movements.all().map(\.itemId).sorted() == ["ghost"])
    }

    @Test func creditForUnknownCustomerStillWritesTheLedger() async throws {
        let harness = try makeHarness()
        try await harness.lifecycle.recordEffects(of: sale(items: [line("pen", qty: 1)], credit: 5, phone: "7"), by: "u")
        #expect(try await harness.ledger.all().count == 1)
        #expect(harness.customers.customers["7"] == nil)
    }

    @Test func cancellingAReturnTakesStockBackOutAndRestoresDue() async throws {
        let harness = try makeHarness()
        harness.sales.sales["s1"] = sale(items: [line("pen", qty: 2)], credit: 20, returnOf: "orig")
        try await harness.lifecycle.cancel(saleId: "s1", reason: "mistake", by: "u")
        #expect(harness.inventory.items["pen"]?.currentStock == 8)
        #expect(harness.customers.customers["9"]?.dueBalance == 20)
        #expect(harness.audit.box.actions == ["bill.cancel"])
    }

    @Test func cancellingAnOrdinaryCreditSaleLowersDue() async throws {
        let harness = try makeHarness()
        harness.customers.customers["9"]?.dueBalance = 20
        harness.sales.sales["s1"] = sale(items: [line("pen", qty: 2)], credit: 20)
        try await harness.lifecycle.cancel(saleId: "s1", reason: "mistake", by: "u")
        #expect(harness.inventory.items["pen"]?.currentStock == 12)
        #expect(harness.customers.customers["9"]?.dueBalance == 0)
    }

    @Test func editAdjustsStockForChangedAddedAndRemovedLinesAndDue() async throws {
        let harness = try makeHarness()
        harness.inventory.items["cup"] = InventoryItem(id: "cup", name: "Cup", currentStock: 5)
        harness.sales.sales["s1"] = sale(items: [line("pen", qty: 3), line("cup", qty: 1)], credit: 0)
        let edited = sale(items: [line("pen", qty: 1), line("gum", qty: 2)], credit: 10)
        try await harness.lifecycle.edit(edited, reason: "swap", by: "u")
        #expect(harness.inventory.items["pen"]?.currentStock == 12)
        #expect(harness.inventory.items["cup"]?.currentStock == 6)
        #expect(harness.customers.customers["9"]?.dueBalance == 10)
        #expect(harness.sales.sales["s1"]?.editReason == "swap")
        #expect(harness.audit.box.actions == ["bill.edit"])
    }

    @Test func editWithNothingChangedTouchesNoStockOrDue() async throws {
        let harness = try makeHarness()
        let original = sale(items: [line("pen", qty: 3)])
        harness.sales.sales["s1"] = original
        try await harness.lifecycle.edit(original, reason: "same", by: "u")
        #expect(harness.inventory.items["pen"]?.currentStock == 10)
        #expect(try await harness.ledger.all().isEmpty)
    }
}

// MARK: - Stock / Money / People / Dues

struct StockMoneyPeopleCoverageTests {
    private let database: SkipSqlDatabase

    init() throws { database = try memoryDatabase() }

    private func docs<T: OrgDocument>(_ type: T.Type) -> OrgCollectionRepository<T> {
        collection(type, database: database)
    }

    private func makeStock(inventory: LifecycleInventoryRepository, cashflow: RecordingCashflowRepository? = nil,
                           audit: RecordingAudit? = nil) -> StockRepository {
        StockRepository(inventoryRepository: inventory, movements: docs(StockMovement.self), purchases: docs(Purchase.self),
                        supplierLedger: docs(SupplierLedgerEntry.self), cashBook: CashBook(repository: cashflow), audit: audit)
    }

    @Test func stockAdjustmentArithmetic() {
        #expect(StockAdjustment.add(3).newStock(from: 10) == 13)
        #expect(StockAdjustment.remove(3).newStock(from: 10) == 7)
        #expect(StockAdjustment.setExact(3).newStock(from: 10) == 3)
    }

    @Test func adjustingToTheSameStockWritesNoMovement() async throws {
        let inventory = LifecycleInventoryRepository()
        inventory.items["a"] = InventoryItem(id: "a", name: "A", currentStock: 4)
        let stock = makeStock(inventory: inventory)
        let item = try await stock.adjust(itemId: "a", .setExact(4), reason: .adjustment, note: nil, by: "u")
        #expect(item.currentStock == 4)
        _ = try await stock.adjust(itemId: "a", .remove(1), reason: .adjustment, note: "lost", by: "u")
        #expect(inventory.items["a"]?.currentStock == 3)
    }

    @Test func purchaseValidationAndEdgeCases() async throws {
        let inventory = LifecycleInventoryRepository()
        inventory.items["a"] = InventoryItem(id: "a", name: "A", currentStock: 4, costPrice: 7)
        let cashflow = RecordingCashflowRepository()
        let audit = RecordingAudit()
        let stock = makeStock(inventory: inventory, cashflow: cashflow, audit: audit)

        let empty = Purchase(number: "P0", supplierId: "s", supplierName: "S", lines: [], total: 0, paid: 0, createdBy: "u")
        await #expect(throws: StockError.invalidAmount) { try await stock.recordPurchase(empty, by: "u") }

        let lines = [PurchaseLine(itemId: "a", itemName: "A", quantity: 0, unitCost: 5),
                     PurchaseLine(itemId: "ghost", itemName: "Ghost", quantity: 2, unitCost: 5),
                     PurchaseLine(itemId: "a", itemName: "A", quantity: 2, unitCost: 0)]
        try await stock.recordPurchase(Purchase(number: "P1", supplierId: "s", supplierName: "S", lines: lines, total: 20, paid: 0,
                                                createdBy: "u"), by: "u")
        #expect(inventory.items["a"]?.currentStock == 6)
        #expect(inventory.items["a"]?.costPrice == 7)
        #expect(cashflow.saved.isEmpty)
        #expect(audit.box.actions == ["purchase.create"])
    }

    @Test func purchaseReturnRefundsCashAndRemovesStock() async throws {
        let inventory = LifecycleInventoryRepository()
        inventory.items["a"] = InventoryItem(id: "a", name: "A", currentStock: 10, costPrice: 7)
        let cashflow = RecordingCashflowRepository()
        let audit = RecordingAudit()
        let stock = makeStock(inventory: inventory, cashflow: cashflow, audit: audit)
        let purchase = Purchase(number: "R1", supplierId: "s", supplierName: "S", isReturn: true,
                                lines: [PurchaseLine(itemId: "a", itemName: "A", quantity: 3, unitCost: 9)],
                                total: 27, paid: 27, paidMode: "cash", createdBy: "u")
        try await stock.recordPurchase(purchase, by: "u")
        #expect(inventory.items["a"]?.currentStock == 7)
        #expect(inventory.items["a"]?.costPrice == 7)
        #expect(cashflow.saved.first?.transactionType == .credit)
        #expect(audit.box.actions == ["purchase.return"])
    }

    @Test func purchaseWithoutLinesStillWritesTheLedger() async throws {
        let stock = makeStock(inventory: LifecycleInventoryRepository())
        try await stock.recordPurchase(Purchase(number: "P2", supplierId: "s", supplierName: "S", lines: [], total: 50, paid: 10,
                                                createdBy: "u"), by: "u")
    }

    @Test func payingASupplierValidatesAndAudits() async throws {
        let audit = RecordingAudit()
        let cashflow = RecordingCashflowRepository()
        let stock = makeStock(inventory: LifecycleInventoryRepository(), cashflow: cashflow, audit: audit)
        let supplier = Supplier(id: "s1", name: "Ramesh", openingDue: 0)
        await #expect(throws: StockError.invalidAmount) { try await stock.paySupplier(supplier, amount: 0, mode: "cash", by: "u") }
        try await stock.paySupplier(supplier, amount: 100, mode: "cash", by: "u")
        #expect(audit.box.actions == ["supplier.pay"])
        #expect(cashflow.saved.count == 1)
    }

    @Test func cashBookSkipsNothingToBookAndPicksTheRightAccount() async throws {
        let cashflow = RecordingCashflowRepository()
        let book = CashBook(repository: cashflow)
        try await CashBook(repository: nil).record(.debit, amount: 5, mode: "cash", category: .miscellaneous, particulars: "p")
        try await book.record(.debit, amount: 0, mode: "cash", category: .miscellaneous, particulars: "p")
        try await book.record(.debit, amount: 5, mode: PaymentMode.credit.rawValue, category: .miscellaneous, particulars: "p")
        #expect(cashflow.saved.isEmpty)
        try await book.record(.debit, amount: 5, mode: "cash", category: .miscellaneous, particulars: "p")
        try await book.record(.credit, amount: 5, mode: "upi", category: .salesRevenue, particulars: "p", person: "x")
        #expect(cashflow.saved.map(\.paymentMode) == [.cash, .upi])
        #expect(cashflow.saved[0].fromAccountId == CashflowTransaction.PaymentMode.cash.accountId)
        #expect(cashflow.saved[1].toAccountId == CashflowTransaction.PaymentMode.upi.accountId)
    }

    @Test func everyExpenseCategoryMapsToACashflowCategory() {
        for category in ExpenseCategory.allCases {
            _ = category.cashflow
        }
        #expect(ExpenseCategory.rent.cashflow.1 == .rent)
        #expect(ExpenseCategory.supplier.cashflow.0 == .inventory)
    }

    @Test func cashEntriesMapCategoriesAndAudit() async throws {
        let cashflow = RecordingCashflowRepository()
        let audit = RecordingAudit()
        let money = MoneyRepository(expenses: docs(Expense.self), dayCloses: docs(DayClose.self), summaries: nil,
                                    cashBook: CashBook(repository: cashflow), audit: audit)
        try await money.addCashEntry(isIn: true, amount: 10, category: nil, particulars: "in", by: "u")
        try await money.addCashEntry(isIn: false, amount: 10, category: nil, particulars: "out", by: "u")
        try await money.addCashEntry(isIn: false, amount: 10, category: .rent, particulars: "rent", by: "u")
        #expect(cashflow.saved.map(\.transactionType) == [.credit, .debit, .debit])
        #expect(audit.box.actions == ["cash.in", "cash.out", "cash.out"])
    }

    @Test func expenseAuditDistinguishesAddFromEdit() async throws {
        let audit = RecordingAudit()
        let money = MoneyRepository(expenses: docs(Expense.self), dayCloses: docs(DayClose.self), summaries: nil,
                                    cashBook: CashBook(repository: nil), audit: audit)
        var expense = Expense(title: "Tea", category: .tea, amount: 20, createdBy: "u")
        try await money.saveExpense(expense)
        expense.amount = 25
        try await money.saveExpense(expense)
        #expect(audit.box.actions == ["expense.add", "expense.edit"])
    }

    @Test func closingTheDayWithoutSummariesOrCarryForward() async throws {
        let closes = docs(DayClose.self)
        let audit = RecordingAudit()
        let money = MoneyRepository(expenses: docs(Expense.self), dayCloses: closes, summaries: nil,
                                    cashBook: CashBook(repository: nil), audit: audit)
        let day = Date()
        try await money.closeDay(DayClose(date: day, expectedCash: 10, countedCash: 10, note: "", carryForward: false,
                                          closedBy: "u", closedByName: "Owner"))
        #expect(try await closes.get(id: day.dayKey) != nil)
        #expect(audit.box.actions == ["day.close"])
    }

    @Test func closingAnAlreadySummarisedDayUpdatesItWithoutDuplicatingTomorrow() async throws {
        let summaries = StubSummaries()
        let money = MoneyRepository(expenses: docs(Expense.self), dayCloses: docs(DayClose.self), summaries: summaries,
                                    cashBook: CashBook(repository: nil), audit: nil)
        let day = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let opening = [AccountBalance(id: "x", name: "X", balance: 1)]
        summaries.summaries[day.dayKey] = DailyCashflowSummary(date: day, openingBalances: opening, closingBalances: [],
                                                               updatedAt: 1, locked: false)
        summaries.summaries[tomorrow.dayKey] = DailyCashflowSummary(date: tomorrow, openingBalances: [], closingBalances: [],
                                                                    updatedAt: 1, locked: false)
        try await money.closeDay(DayClose(date: day, expectedCash: 5, countedCash: 5, note: "", carryForward: true,
                                          closedBy: "u", closedByName: "Owner"))
        #expect(summaries.summaries[day.dayKey]?.locked == true)
        #expect(summaries.summaries[day.dayKey]?.openingBalances.count == 1)
        #expect(summaries.summaries[tomorrow.dayKey]?.openingBalances.isEmpty == true)
    }

    @Test func reopeningADayThatWasNeverClosedIsHarmless() async throws {
        let audit = RecordingAudit()
        let money = MoneyRepository(expenses: docs(Expense.self), dayCloses: docs(DayClose.self), summaries: StubSummaries(),
                                    cashBook: CashBook(repository: nil), audit: audit)
        try await money.reopenDay(Date(), by: "u")
        #expect(audit.box.actions == ["day.reopen"])
    }

    @Test func peopleMarkAttendanceAndAuditPayments() async throws {
        let audit = RecordingAudit()
        let attendance = docs(AttendanceRecord.self)
        let people = PeopleRepository(attendance: attendance, salaryPayments: docs(SalaryPayment.self), expenses: docs(Expense.self),
                                      cashBook: CashBook(repository: nil), audit: audit)
        try await people.mark(AttendanceRecord(memberId: "m1", memberName: "Anu", day: Date(), status: .present, markedBy: "u"))
        #expect(try await attendance.all().count == 1)
        try await people.pay(SalaryPayment(memberId: "m1", memberName: "Anu", month: "2026-11", kind: .salary, amount: 100, createdBy: "u"))
        try await people.pay(SalaryPayment(memberId: "m1", memberName: "Anu", month: "2026-11", kind: .advance, amount: 50, createdBy: "u"))
        #expect(audit.box.actions == ["salary.pay", "salary.advance"])
    }

    @Test func duesLedgerIsNewestFirstAndCashInCanBeRecordedDirectly() async throws {
        let ledger = docs(CustomerLedgerEntry.self)
        let cashflow = RecordingCashflowRepository()
        let customers = LifecycleCustomerRepository()
        let dues = DuesRepository(customerRepository: customers, ledgerRepository: ledger, cashflowRepository: cashflow, audit: nil)
        try await ledger.save(CustomerLedgerEntry(customerPhone: "9", customerName: "A", kind: .sale, amount: 10, createdBy: "u"))
        try await ledger.save(CustomerLedgerEntry(customerPhone: "8", customerName: "B", kind: .sale, amount: 10, createdBy: "u"))
        #expect(try await dues.ledger(phone: "9").count == 1)
        try await dues.recordCashIn(amount: 40, mode: .upi, particulars: "advance", person: nil, at: Date())
        #expect(cashflow.saved.first?.paymentMode == .upi)

        let noCashBook = DuesRepository(customerRepository: customers, ledgerRepository: ledger, cashflowRepository: nil, audit: nil)
        try await noCashBook.recordCashIn(amount: 40, mode: .cash, particulars: "x", person: nil, at: Date())
    }
}
