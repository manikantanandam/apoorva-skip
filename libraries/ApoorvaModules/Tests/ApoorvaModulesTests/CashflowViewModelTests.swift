//
//  CashflowViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
@testable import ApoorvaModules

private final class StubCashflowRepository: CashflowTransactionRepositoryProtocol, @unchecked Sendable {
    var items: [CashflowTransaction]
    var updated: [CashflowTransaction] = []
    var syncCalls: [Bool] = []
    var failSync = false

    init(items: [CashflowTransaction] = []) { self.items = items }

    func getCashflowTransactions() async throws -> [CashflowTransaction] { items }
    func saveCashflowTransaction(transaction: CashflowTransaction) async throws { items.append(transaction) }
    func updateCashflowTransaction(_ transaction: CashflowTransaction) async throws { updated.append(transaction) }
    func deleteCashflowTransaction(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {
        syncCalls.append(force)
        if failSync { throw NSError(domain: "test", code: 1) }
    }
}

private func txn(_ particulars: String, type: CashflowTransaction.TransactionType, mode: CashflowTransaction.PaymentMode,
                 daysAgo: Int = 0, amount: Double = 100, person: String? = nil) -> CashflowTransaction {
    CashflowTransaction(timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                        particulars: particulars, amount: amount, transactionType: type, paymentMode: mode,
                        category: .inventory, fromAccountId: "", toAccountId: "", person: person,
                        timestampInMs: 0, updatedAtInMs: 0)
}

@MainActor
struct CashflowViewModelTests {
    private func loaded(_ items: [CashflowTransaction]) async -> (CashflowTransactionListViewModel, StubCashflowRepository) {
        let repo = StubCashflowRepository(items: items)
        let model = CashflowTransactionListViewModel(repository: repo)
        await model.prepareDate()
        return (model, repo)
    }

    @Test func prepareDateLoadsSyncsAndExtractsFilters() async {
        let (model, repo) = await loaded([txn("a", type: .credit, mode: .cash), txn("b", type: .debit, mode: .upi)])
        #expect(model.transactions.count == 2)
        #expect(repo.syncCalls == [false])
        #expect(model.availableCategories.first == "All")
        #expect(model.availableCategories.count == 2)
    }

    @Test func prepareDateSwallowsSyncFailure() async {
        let repo = StubCashflowRepository(items: [txn("a", type: .credit, mode: .cash)])
        repo.failSync = true
        let model = CashflowTransactionListViewModel(repository: repo)
        await model.prepareDate()
        #expect(model.transactions.isEmpty)
    }

    @Test func typeAndPaymentFiltersNarrowResults() async {
        let (model, _) = await loaded([txn("a", type: .credit, mode: .cash), txn("b", type: .debit, mode: .upi)])
        model.typeFilter = .credit
        #expect(model.transactions.map(\.particulars) == ["a"])
        model.typeFilter = .debit
        #expect(model.transactions.map(\.particulars) == ["b"])
        model.typeFilter = .all
        model.paymentModeFilter = .upi
        #expect(model.transactions.map(\.particulars) == ["b"])
        model.paymentModeFilter = .cash
        #expect(model.transactions.map(\.particulars) == ["a"])
    }

    @Test func dateFiltersIncludeOnlyMatchingDays() async {
        let (model, _) = await loaded([txn("today", type: .credit, mode: .cash),
                                       txn("old", type: .credit, mode: .cash, daysAgo: 400)])
        model.dateFilter = .today
        #expect(model.transactions.map(\.particulars) == ["today"])
        model.dateFilter = .last7Days
        #expect(model.transactions.map(\.particulars) == ["today"])
        model.dateFilter = .last3Months
        #expect(model.transactions.map(\.particulars) == ["today"])
        model.dateFilter = .thisYear
        #expect(model.transactions.contains { $0.particulars == "today" })
        model.dateFilter = .thisMonth
        #expect(model.transactions.contains { $0.particulars == "today" })
        model.dateFilter = .all
        #expect(model.transactions.count == 2)
    }

    @Test func customRangeUsesStartAndEnd() async {
        let (model, _) = await loaded([txn("recent", type: .credit, mode: .cash, daysAgo: 1),
                                       txn("old", type: .credit, mode: .cash, daysAgo: 30)])
        model.dateFilter = .custom
        model.customStartDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        model.customEndDate = Date()
        #expect(model.transactions.map(\.particulars) == ["recent"])
    }

    @Test func categoryFilterResetsWhenMissingAfterReload() async {
        let (model, _) = await loaded([txn("a", type: .credit, mode: .cash)])
        model.categoryFilter = "Nope"
        await model.prepareDate()
        #expect(model.categoryFilter == "All")
        #expect(model.subCategoryFilter == "All")
    }

    @Test func sortOptionOrdersByTimestamp() async {
        let (model, _) = await loaded([txn("new", type: .credit, mode: .cash), txn("old", type: .credit, mode: .cash, daysAgo: 2)])
        model.sortOption = .oldest
        #expect(model.transactions.first?.particulars == "old")
        model.sortOption = .newest
        #expect(model.transactions.first?.particulars == "new")
    }

    @Test func updateAssignsAccountIdsAndPersists() async {
        let (model, repo) = await loaded([txn("in", type: .credit, mode: .cash), txn("out", type: .debit, mode: .upi)])
        await model.update()
        #expect(repo.updated.count == 2)
        #expect(repo.updated.first { $0.particulars == "in" }?.toAccountId == CashflowTransaction.PaymentMode.cash.accountId)
        #expect(repo.updated.first { $0.particulars == "out" }?.fromAccountId == CashflowTransaction.PaymentMode.upi.accountId)
    }

    @Test func forceSyncReloadsTransactions() async {
        let (model, repo) = await loaded([])
        repo.items = [txn("late", type: .credit, mode: .cash)]
        await model.forceSync()
        #expect(repo.syncCalls.last == true)
        #expect(model.transactions.count == 1)
    }

    @Test func csvEscapesSpecialCharacters() async throws {
        let (model, _) = await loaded([txn("Tea, \"special\"", type: .debit, mode: .cash, person: "Ravi")])
        let url = try #require(model.generateCSV())
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("Date,Category,Sub Category,Particulars,Type,Payment Mode,Person,Amount\n"))
        #expect(text.contains("\"Tea, \"\"special\"\"\""))
        #expect(text.contains("Ravi"))
        try? FileManager.default.removeItem(at: url)
    }
}
