//
//  StockMoneyPeopleRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
@testable import ApoorvaServices
@testable import ApoorvaRepository

final class StubSummaries: DailyCashflowSummaryRepositoryProtocol, @unchecked Sendable {
    var summaries: [String: DailyCashflowSummary] = [:]
    func getDailyCashflowSummaries() async throws -> [DailyCashflowSummary] { Array(summaries.values) }
    func getDailyCashflowSummary(id: String) async throws -> DailyCashflowSummary? { summaries[id] }
    func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws { summaries[summary.id] = summary }
    func updateDailyCashflowSummary(summary: DailyCashflowSummary) async throws { summaries[summary.id] = summary }
    func deleteDailyCashflowSummary(id: String) async throws { summaries[id] = nil }
    func sync(force: Bool) async throws {}
    func refresh(for date: String) async throws {}
}

struct StockMoneyPeopleRepositoryTests {
    private let database: SkipSqlDatabase

    init() throws {
        database = try SkipSqlDatabase(filepath: ":memory:")
    }

    private func collection<T: OrgDocument>(_ type: T.Type) -> OrgCollectionRepository<T> {
        OrgCollectionRepository<T>(storage: OrgCollectionLocalStorage(database: database), service: OrgCollectionService(store: InMemoryStore()),
                                   context: FixedOrgContext(orgId: nil), syncStorage: SyncStorage(db: database))
    }

    @Test func adjustingStockWritesAMovement() async throws {
        let inventory = LifecycleInventoryRepository()
        inventory.items["teddy"] = InventoryItem(id: "teddy", name: "Teddy", currentStock: 3)
        let movements = collection(StockMovement.self)
        let audit = RecordingAudit()
        let stock = StockRepository(inventoryRepository: inventory, movements: movements, purchases: collection(Purchase.self),
                                    supplierLedger: collection(SupplierLedgerEntry.self), cashBook: CashBook(repository: nil), audit: audit)
        let item = try await stock.adjust(itemId: "teddy", .add(24), reason: .purchase, note: nil, by: "u1")
        #expect(item.currentStock == 27)
        try await stock.adjust(itemId: "teddy", .setExact(25), reason: .adjustment, note: "count", by: "u1")
        #expect(inventory.items["teddy"]?.currentStock == 25)
        #expect(Set(try await movements.all().map(\.delta)) == [24, -2])
        #expect(audit.box.actions == ["stock.adjust", "stock.adjust"])
        await #expect(throws: StockError.itemNotFound) { try await stock.adjust(itemId: "x", .add(1), reason: .purchase, note: nil, by: "u1") }
    }

    @Test func purchaseOnPartCreditUpdatesStockCostLedgerAndCash() async throws {
        let inventory = LifecycleInventoryRepository()
        inventory.items["atta"] = InventoryItem(id: "atta", name: "Atta", currentStock: 2)
        let ledger = collection(SupplierLedgerEntry.self)
        let cashflow = RecordingCashflowRepository()
        let stock = StockRepository(inventoryRepository: inventory, movements: collection(StockMovement.self), purchases: collection(Purchase.self),
                                    supplierLedger: ledger, cashBook: CashBook(repository: cashflow), audit: nil)
        let supplier = Supplier(id: "s1", name: "Ramesh Traders", openingDue: 1000)
        let purchase = Purchase(number: "P-001", supplierId: "s1", supplierName: supplier.name,
                                lines: [PurchaseLine(itemId: "atta", itemName: "Atta", quantity: 10, unitCost: 240)],
                                total: 2400, paid: 400, paidMode: "upi", createdBy: "u1")
        try await stock.recordPurchase(purchase, by: "u1")

        #expect(inventory.items["atta"]?.currentStock == 12)
        #expect(inventory.items["atta"]?.costPrice == 240)
        let entries = try await ledger.all()
        #expect(entries.owed(to: supplier) == 3000)
        #expect(cashflow.saved.first?.transactionType == .debit)
        #expect(cashflow.saved.first?.paymentMode == .upi)

        try await stock.paySupplier(supplier, amount: 3000, mode: "cash", by: "u1")
        #expect(try await ledger.all().owed(to: supplier) == 0)
    }

    @Test func closingTheDayLocksTheSummaryAndCarriesCashForward() async throws {
        let summaries = StubSummaries()
        let closes = collection(DayClose.self)
        let money = MoneyRepository(expenses: collection(Expense.self), dayCloses: closes, summaries: summaries,
                                    cashBook: CashBook(repository: nil), audit: nil)
        let today = Date()
        try await money.closeDay(DayClose(date: today, expectedCash: 8250, countedCash: 8200, note: "float", carryForward: true,
                                          closedBy: "u1", closedByName: "Owner"))
        let cash = CashflowTransaction.PaymentMode.cash.accountId
        #expect(summaries.summaries[today.dayKey]?.locked == true)
        #expect(summaries.summaries[today.dayKey]?.closingBalances.first { $0.id == cash }?.balance == 8200)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        #expect(summaries.summaries[tomorrow.dayKey]?.openingBalances.first?.balance == 8200)
        #expect(try await closes.get(id: today.dayKey)?.difference == -50)

        try await money.reopenDay(today, by: "u1")
        #expect(summaries.summaries[today.dayKey]?.locked == false)
        #expect(try await closes.get(id: today.dayKey)?.isDeleted == true)
    }

    @Test func expensesBookOnceAndSalaryBecomesAnExpense() async throws {
        let cashflow = RecordingCashflowRepository()
        let expenses = collection(Expense.self)
        let money = MoneyRepository(expenses: expenses, dayCloses: collection(DayClose.self), summaries: nil,
                                    cashBook: CashBook(repository: cashflow), audit: nil)
        var bill = Expense(title: "Electricity", category: .electricity, amount: 3450, createdBy: "u1")
        try await money.saveExpense(bill)
        bill.amount = 3500
        try await money.saveExpense(bill)
        #expect(cashflow.saved.count == 1)

        let people = PeopleRepository(attendance: collection(AttendanceRecord.self), salaryPayments: collection(SalaryPayment.self),
                                      expenses: expenses, cashBook: CashBook(repository: cashflow), audit: nil)
        try await people.pay(SalaryPayment(memberId: "m1", memberName: "Anu", month: "2026-11", kind: .salary, amount: 14840, createdBy: "u1"))
        try await people.pay(SalaryPayment(memberId: "m1", memberName: "Anu", month: "2026-11", kind: .advance, amount: 2000, createdBy: "u1"))
        let all = try await expenses.all()
        #expect(all.filter { $0.category == .salary }.map(\.amount) == [14840])
        #expect(cashflow.saved.count == 3)
    }
}
