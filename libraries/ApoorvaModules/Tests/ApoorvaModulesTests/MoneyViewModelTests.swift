//
//  MoneyViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
@testable import ApoorvaModules

private final class RecordingMoney: MoneyRepositoryProtocol, @unchecked Sendable {
    var cashEntries: [(isIn: Bool, amount: Double, particulars: String)] = []
    var expenses: [Expense] = []
    var closes: [DayClose] = []
    var reopened: [Date] = []
    var fail = false

    func addCashEntry(isIn: Bool, amount: Double, category: ExpenseCategory?, particulars: String, by actorId: String) async throws {
        if fail { throw NSError(domain: "test", code: 1) }
        cashEntries.append((isIn, amount, particulars))
    }
    func saveExpense(_ expense: Expense) async throws {
        if fail { throw NSError(domain: "test", code: 1) }
        expenses.append(expense)
    }
    func closeDay(_ close: DayClose) async throws {
        if fail { throw NSError(domain: "test", code: 1) }
        closes.append(close)
    }
    func reopenDay(_ day: Date, by actorId: String) async throws { reopened.append(day) }
    var updatedEntries: [CashflowTransaction] = []
    var deletedEntries: [CashflowTransaction] = []
    func updateCashEntry(_ entry: CashflowTransaction, by actorId: String) async throws {
        if fail { throw NSError(domain: "test", code: 1) }
        updatedEntries.append(entry)
    }
    func deleteCashEntry(_ entry: CashflowTransaction, by actorId: String) async throws {
        if fail { throw NSError(domain: "test", code: 1) }
        deletedEntries.append(entry)
    }
}

private final class FixedCashflowRepository: CashflowTransactionRepositoryProtocol, @unchecked Sendable {
    var items: [CashflowTransaction] = []
    func getCashflowTransactions() async throws -> [CashflowTransaction] { items }
    func saveCashflowTransaction(transaction: CashflowTransaction) async throws {}
    func updateCashflowTransaction(_ transaction: CashflowTransaction) async throws {}
    func deleteCashflowTransaction(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {}
}

private final class FixedInventory: InventoryItemRepositoryProtocol, @unchecked Sendable {
    func getInventoryItems() async throws -> [InventoryItem] { [InventoryItem(id: "pen", name: "Pen")] }
    func saveInventoryItem(item: InventoryItem) async throws {}
    func updateInventoryItem(_ item: InventoryItem) async throws {}
    func deleteInventoryItem(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {}
    func lastSyncedAt() async throws -> Date? { nil }
}

private func makeSale(_ total: Double, mode: PaymentMode = .cash, isReturn: Bool = false, daysAgo: Int = 0) -> Sale {
    var sale = Sale(id: UUID().uuidString, staffId: "u1", customerPhone: "", customerName: "C",
                    items: [SaleItem(categoryId: "pen", categoryName: "Pen", qty: 1, stickerPrice: total, finalPrice: total, discountType: .percentage)],
                    subtotal: total, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: total,
                    payments: [mode: total],
                    timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                    source: "POS", status: "Completed", whatsappStatus: "unsent")
    if isReturn { sale.returnOfSaleId = "orig" }
    return sale
}

@MainActor
struct CashDayViewModelTests {
    private func makeDay() -> (CashDayViewModel, StubSaleRepository, StubOrgRepository<DayClose>) {
        let sales = StubSaleRepository()
        sales.sales = [makeSale(500), makeSale(200, mode: .upi)]
        let closes = StubOrgRepository<DayClose>()
        let model = CashDayViewModel(summaries: StubDailyCashflowRepository(), saleRepository: sales,
                                     cashflowRepository: FixedCashflowRepository(), dayCloses: closes)
        return (model, sales, closes)
    }

    @Test func loadComputesDayAndClosedState() async {
        let (model, _, closes) = makeDay()
        await model.load()
        #expect(model.day?.cashSales == 500)
        #expect(model.day?.byMode[.upi] == 200)
        #expect(model.isToday)
        #expect(!model.isClosed)
        try? await closes.save(DayClose(date: Date(), expectedCash: 500, countedCash: 500, note: "", carryForward: true, closedBy: "u", closedByName: "U"))
        await model.load()
        #expect(model.isClosed)
    }

    @Test func closedDayKeysCombineDayClosesAndSavedClosingBalances() async {
        let summaries = StubDailyCashflowRepository()
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let cash = CashflowTransaction.PaymentMode.cash.accountId
        summaries.saved = [
            // Legacy day with a saved closing balance.
            DailyCashflowSummary(date: twoDaysAgo, openingBalances: [], closingBalances: [AccountBalance(id: cash, name: "Cash", balance: 900)],
                                 updatedAt: 0, locked: true),
            // Open day: no closing balance saved yet.
            DailyCashflowSummary(date: threeDaysAgo, openingBalances: [AccountBalance(id: cash, name: "Cash", balance: 100)],
                                 closingBalances: [], updatedAt: 0, locked: false)
        ]
        let closes = StubOrgRepository<DayClose>()
        try? await closes.save(DayClose(date: Date(), expectedCash: 500, countedCash: 500, note: "", carryForward: true, closedBy: "u", closedByName: "U"))
        var reopened = DayClose(date: calendar.date(byAdding: .day, value: -5, to: Date())!, expectedCash: 1, countedCash: 1, note: "",
                                carryForward: true, closedBy: "u", closedByName: "U")
        reopened.isDeleted = true
        try? await closes.save(reopened)
        let model = CashDayViewModel(summaries: summaries, saleRepository: StubSaleRepository(),
                                     cashflowRepository: FixedCashflowRepository(), dayCloses: closes)
        await model.load()
        #expect(model.closedDayKeys == [Date().dayKey, twoDaysAgo.dayKey])
    }

    @Test func goToJumpsToAPastDayAndIgnoresTheFuture() async {
        let (model, _, _) = makeDay()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        await model.go(to: lastWeek)
        #expect(Calendar.current.isDate(model.date, inSameDayAs: lastWeek))
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        await model.go(to: tomorrow)
        #expect(Calendar.current.isDate(model.date, inSameDayAs: lastWeek))
    }

    @Test func stepMovesBackButNotIntoFuture() async {
        let (model, _, _) = makeDay()
        await model.step(1)
        #expect(model.isToday)
        await model.step(-1)
        #expect(!model.isToday)
    }

    @Test func saleSignHelpers() {
        let refund = makeSale(100, isReturn: true)
        #expect(refund.paid(.cash) == -100)
        #expect(refund.signedTotal == -100)
        #expect(makeSale(100).signedTotal == 100)
    }
}

@MainActor
struct CashEntryAndCloseTests {
    @Test func cashEntryBuildsParticularsAndSaves() async {
        let money = RecordingMoney()
        let model = CashEntryViewModel(money: money, actorId: "u1")
        #expect(await model.save() == false)
        model.amountText = "250"
        model.note = "morning"
        #expect(model.particulars == "Supplier payment · morning")
        #expect(await model.save())
        model.isIn = true
        model.note = ""
        #expect(model.particulars == "Cash in")
        #expect(await model.save())
        #expect(money.cashEntries.count == 2)
        for purpose in CashEntryViewModel.Purpose.allCases { _ = purpose.category; _ = purpose.title }
    }

    @Test func cashEntryFailureSetsError() async {
        let money = RecordingMoney()
        money.fail = true
        let model = CashEntryViewModel(money: money, actorId: "u1")
        model.amountText = "10"
        #expect(await model.save() == false)
        #expect(model.errorMessage != nil)
    }

    @Test func closeDayUsesExpectedAndCounted() async {
        let sales = StubSaleRepository()
        sales.sales = [makeSale(1000)]
        let dayModel = CashDayViewModel(summaries: StubDailyCashflowRepository(), saleRepository: sales,
                                        cashflowRepository: FixedCashflowRepository(), dayCloses: StubOrgRepository<DayClose>())
        let money = RecordingMoney()
        let model = DayCloseViewModel(date: Date(), dayViewModel: dayModel, money: money, actorId: "u1", actorName: "Kiran")
        await model.load()
        #expect(model.expected == 1000)
        #expect(model.countedText == "1000")
        model.countedText = "950"
        #expect(model.difference == -50)
        #expect(model.tomorrow > model.date)
        #expect(await model.close())
        #expect(money.closes.first?.countedCash == 950)
        model.countedText = ""
        #expect(await model.close() == false)
        money.fail = true
        model.countedText = "1"
        #expect(await model.close() == false)
        #expect(model.errorMessage != nil)
    }
}

@MainActor
struct CashHistoryAndExpenseTests {
    @Test func historyListsDaysAndExportsCSV() async {
        let sales = StubSaleRepository()
        sales.sales = [makeSale(100)]
        let closes = StubOrgRepository<DayClose>([DayClose(date: Date(), expectedCash: 100, countedCash: 90, note: "short", carryForward: true, closedBy: "u", closedByName: "U")])
        let money = RecordingMoney()
        let model = CashHistoryViewModel(dayCloses: closes, saleRepository: sales, money: money, actorId: "u1")
        await model.load()
        #expect(model.rows.first?.close != nil)
        #expect(model.rows.first?.hadSales == true)
        #expect(!model.title.isEmpty)
        #expect(model.csv.hasPrefix("Date,Expected,Counted,Difference,Closed by,Note"))
        #expect(model.csv.contains("\"short\""))
        if let row = model.rows.first { await model.reopen(row) }
        #expect(money.reopened.count == 1)
        await model.step(1)
        await model.step(-1)
        #expect(model.rows.first?.date != nil)
        if model.rows.count > 1 { #expect(model.csv.contains("Shop closed") || model.csv.contains("Not closed")) }
    }

    @Test func expensesFilterByMonthAndGroupByCategory() async {
        let repo = StubOrgRepository<Expense>([
            Expense(title: "Power", category: .electricity, amount: 300, createdBy: "u"),
            Expense(title: "Tea", category: .tea, amount: 50, createdBy: "u")
        ])
        let model = ExpensesViewModel(repository: repo)
        await model.load()
        #expect(model.expenses.count == 2)
        #expect(model.total == 350)
        #expect(model.byCategory.first?.category == .electricity)
        #expect(model.title.contains("₹") || !model.title.isEmpty)
        await model.step(-1)
        #expect(model.expenses.isEmpty)
        await model.step(1)
        #expect(model.expenses.count == 2)
    }

    @Test func expenseFormCreatesAndEdits() async throws {
        let repo = StubOrgRepository<Expense>()
        let money = RecordingMoney()
        let model = ExpenseFormViewModel(expenseId: nil, repository: repo, money: money, actorId: "u1")
        #expect(!model.canSave)
        #expect(await model.save() == false)
        model.amountText = "120"
        #expect(model.displayTitle == "\(model.category.title) bill")
        #expect(await model.save())
        let saved = try #require(money.expenses.first)
        #expect(saved.amount == 120)

        try await repo.save(saved)
        let editor = ExpenseFormViewModel(expenseId: saved.id, repository: repo, money: money, actorId: "u1")
        await editor.load()
        #expect(editor.amountText == "120")
        editor.title = "Renamed"
        #expect(await editor.save())
        #expect(money.expenses.last?.title == "Renamed")

        money.fail = true
        #expect(await editor.save() == false)
        #expect(editor.errorMessage != nil)
    }
}

@MainActor
struct DailySummaryViewModelTests {
    @Test func loadsTotalsAndBuildsShareText() async {
        let sales = StubSaleRepository()
        sales.sales = [makeSale(400), makeSale(100, mode: .upi)]
        let ledger = StubOrgRepository<CustomerLedgerEntry>([
            CustomerLedgerEntry(customerPhone: "1", customerName: "A", kind: .payment, amount: -75, createdBy: "u"),
            CustomerLedgerEntry(customerPhone: "1", customerName: "A", kind: .sale, amount: 60, createdBy: "u")
        ])
        let expenses = StubOrgRepository<Expense>([Expense(title: "Tea", category: .tea, amount: 20, createdBy: "u")])
        let closes = StubOrgRepository<DayClose>()
        let model = DailySummaryViewModel(saleRepository: sales, inventoryRepository: FixedInventory(), ledger: ledger,
                                          expenseRepository: expenses, dayCloses: closes, shopName: "Glitz")
        await model.load()
        #expect(model.sales == 500)
        #expect(model.bills == 2)
        #expect(model.expenses == 20)
        #expect(model.duesCollected == 75)
        #expect(model.newCredit == 60)
        #expect(!model.isClosed)
        let text = model.shareText
        #expect(text.contains("*Glitz*"))
        #expect(text.contains("Top item: Pen"))
        #expect(text.contains("Dues collected"))
    }
}

@MainActor
struct CashEntryEditTests {
    private func entry(id: String = "e1", type: CashflowTransaction.TransactionType = .credit,
                       mode: CashflowTransaction.PaymentMode = .cash, deleted: Bool = false) -> CashflowTransaction {
        CashflowTransaction(id: id, timestamp: Date(timeIntervalSince1970: 1_000), particulars: "No particulars", amount: 600,
                            transactionType: type, paymentMode: mode, category: .salesRevenue,
                            fromAccountId: type == .debit ? mode.accountId : "", toAccountId: type == .credit ? mode.accountId : "",
                            isDeleted: deleted, timestampInMs: 1_000, updatedAtInMs: 1_000)
    }

    private func makeSUT(_ items: [CashflowTransaction]) -> (CashEntryEditViewModel, RecordingMoney) {
        let cashflow = FixedCashflowRepository()
        cashflow.items = items
        let money = RecordingMoney()
        return (CashEntryEditViewModel(entryId: "e1", cashflowRepository: cashflow, money: money, actorId: "u1"), money)
    }

    @Test func loadFillsTheFormFromTheEntry() async {
        let (model, _) = makeSUT([entry()])
        await model.load()
        #expect(model.isLoaded)
        #expect(model.isIn)
        #expect(model.isCash)
        #expect(model.amountText == "600")
        #expect(model.particulars == "No particulars")
    }

    @Test func aMissingOrDeletedEntryDoesNotLoad() async {
        let (missing, _) = makeSUT([])
        await missing.load()
        #expect(!missing.isLoaded)
        #expect(missing.errorMessage != nil)
        let (deleted, _) = makeSUT([entry(deleted: true)])
        await deleted.load()
        #expect(!deleted.isLoaded)
    }

    @Test func editingTextAndAmountKeepsAccountsAndIdentity() async {
        let (model, money) = makeSUT([entry()])
        await model.load()
        model.amountText = "650"
        model.particulars = " Float "
        #expect(await model.save())
        let saved = money.updatedEntries.first
        #expect(saved?.id == "e1")
        #expect(saved?.amount == 650)
        #expect(saved?.particulars == "Float")
        #expect(saved?.timestamp == Date(timeIntervalSince1970: 1_000))
        #expect(saved?.toAccountId == CashflowTransaction.PaymentMode.cash.accountId)
        #expect(saved?.fromAccountId == "")
    }

    @Test func changingDirectionOrModeRebuildsTheAccounts() async {
        let (model, money) = makeSUT([entry()])
        await model.load()
        model.isIn = false
        model.isCash = false
        #expect(await model.save())
        let saved = money.updatedEntries.first
        #expect(saved?.transactionType == .debit)
        #expect(saved?.paymentMode == .upi)
        #expect(saved?.fromAccountId == CashflowTransaction.PaymentMode.upi.accountId)
        #expect(saved?.toAccountId == "")
    }

    @Test func aLegacyEntryWithAnUnknownTypeIsNotRewrittenUnlessChanged() async {
        let (model, money) = makeSUT([entry(type: .unknown, mode: .unknown)])
        await model.load()
        model.particulars = "Tea"
        #expect(await model.save())
        #expect(money.updatedEntries.first?.transactionType == .unknown)
        #expect(money.updatedEntries.first?.paymentMode == .unknown)
    }

    @Test func saveNeedsAPositiveAmountAndReportsFailures() async {
        let (model, money) = makeSUT([entry()])
        await model.load()
        model.amountText = ""
        #expect(!model.canSave)
        #expect(await model.save() == false)
        model.amountText = "10"
        money.fail = true
        #expect(await model.save() == false)
        #expect(model.errorMessage != nil)
    }

    @Test func deleteSoftDeletesTheOriginalEntry() async {
        let (model, money) = makeSUT([entry()])
        await model.load()
        #expect(await model.delete())
        #expect(money.deletedEntries.map(\.id) == ["e1"])
    }
}
