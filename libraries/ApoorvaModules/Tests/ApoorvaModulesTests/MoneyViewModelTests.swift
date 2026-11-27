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
    var cashEntryCategories: [(CashflowCategory, CashflowSubCategory?)] = []
    var cashEntryAccounts: [Account?] = []
    var transfers: [(amount: Double, from: Account, to: Account, particulars: String)] = []
    var transferIds: [String] = []
    func addTransfer(id: String, amount: Double, from: Account, to: Account, particulars: String, by actorId: String) async throws {
        transferIds.append(id)
        if fail { throw NSError(domain: "test", code: 1) }
        transfers.append((amount, from, to, particulars))
    }
    var expenses: [Expense] = []
    var closes: [DayClose] = []
    var reopened: [Date] = []
    var fail = false

    func addCashEntry(isIn: Bool, amount: Double, category: CashflowCategory, subCategory: CashflowSubCategory?,
                      account: Account?, particulars: String, by actorId: String) async throws {
        if fail { throw NSError(domain: "test", code: 1) }
        cashEntries.append((isIn, amount, particulars))
        cashEntryCategories.append((category, subCategory))
        cashEntryAccounts.append(account)
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

    @Test func aFailedAccountLookupShowsNoTotals() async {
        let model = CashDayViewModel(summaries: StubDailyCashflowRepository(), saleRepository: StubSaleRepository(),
                                     cashflowRepository: FixedCashflowRepository(), dayCloses: StubOrgRepository<DayClose>(),
                                     loadAccounts: { throw NSError(domain: "test", code: 1) })
        await model.load()
        #expect(model.day == nil)
        #expect(model.errorMessage != nil)
    }

    @Test func aDeletedCashAccountKeepsItsPastTransfers() async {
        var deletedCash = Account(id: "acc-old-cash", name: "Old till", type: .cash, currentBalance: 0)
        deletedCash.isDeleted = true
        let accounts = [deletedCash] // a `let` copy: Swift 6 rejects capturing the `var` in the @Sendable loader
        let cashflow = FixedCashflowRepository()
        cashflow.items = [CashflowTransaction(timestamp: Date(), particulars: "Deposit", amount: 500, transactionType: .debit,
                                              paymentMode: .cash, category: .internalTransfer, subCategory: .internalTransfer,
                                              fromAccountId: "acc-old-cash", toAccountId: "acc-bank",
                                              timestampInMs: 0, updatedAtInMs: 0)]
        let model = CashDayViewModel(summaries: StubDailyCashflowRepository(), saleRepository: StubSaleRepository(),
                                     cashflowRepository: cashflow, dayCloses: StubOrgRepository<DayClose>(),
                                     loadAccounts: { accounts })
        await model.load()
        #expect(model.day?.cashOut == 500)
        #expect(model.accounts.isEmpty)            // still hidden from pickers and rows
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
        model.selectCategory(.inventory)
        model.selectSubCategory(.readyStock)
        #expect(model.particulars == "Ready Stock · morning")
        #expect(await model.save())
        model.setDirection(true)
        model.note = ""
        #expect(model.particulars == "Cash in")
        #expect(await model.save())
        #expect(money.cashEntries.count == 2)
        #expect(money.cashEntryCategories.map(\.0) == [.inventory, .salesRevenue])
        #expect(money.cashEntryCategories.map(\.1) == [.readyStock, .salesRevenue])
    }

    @Test func choosingACategoryOffersItsSubCategoriesOnly() {
        let model = CashEntryViewModel(money: RecordingMoney(), actorId: "u1")
        #expect(model.category == .miscellaneous)
        #expect(model.subCategory == .general)
        model.selectCategory(.salary)
        #expect(model.subCategories == [.wages, .advances, .bonuses])
        #expect(model.subCategory == .wages)
        model.selectSubCategory(.petrol)   // not a salary sub-category: ignored
        #expect(model.subCategory == .wages)
        model.selectSubCategory(.advances)
        #expect(model.subCategory == .advances)
        #expect(model.categories.contains(.salary))
        #expect(!model.categories.contains(.unknown))
    }

    @Test func cashEntryUsesTheChosenAccount() async {
        let cash = Account(id: "acc-cash", name: "Cash", type: .cash, currentBalance: 0)
        let bank = Account(id: "acc-bank", name: "HDFC", type: .bank, currentBalance: 0)
        let money = RecordingMoney()
        let model = CashEntryViewModel(money: money, actorId: "u1", loadAccounts: { [bank, cash] })
        await model.load()
        #expect(model.selectedAccountId == "acc-cash")   // defaults to the cash account
        #expect(model.accountTitle == "From account")
        model.setDirection(true)
        #expect(model.accountTitle == "To account")
        model.selectAccount("acc-bank")
        model.selectAccount("missing")                   // ignored
        model.amountText = "100"
        #expect(await model.save())
        #expect(money.cashEntryAccounts.first.flatMap { $0 }?.id == "acc-bank")
    }

    @Test func cashEntryWithoutAnyAccountsFallsBackToTheCashAccount() async {
        let money = RecordingMoney()
        let model = CashEntryViewModel(money: money, actorId: "u1")
        await model.load()
        #expect(model.accounts.isEmpty)
        model.amountText = "50"
        #expect(await model.save())
        #expect(money.cashEntryAccounts.count == 1)
        #expect(money.cashEntryAccounts.first.flatMap { $0 } == nil)
    }

    @Test func directionResetsTheDefaultCategory() {
        let model = CashEntryViewModel(money: RecordingMoney(), actorId: "u1")
        model.setDirection(true)
        #expect(model.category == .salesRevenue)
        model.setDirection(false)
        #expect(model.category == .miscellaneous)
        #expect(model.subCategory == .general)
        #expect(model.particulars == "Miscellaneous")
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

    private func makeSUT(_ items: [CashflowTransaction], accounts: [Account] = []) -> (CashEntryEditViewModel, RecordingMoney) {
        let cashflow = FixedCashflowRepository()
        cashflow.items = items
        let money = RecordingMoney()
        return (CashEntryEditViewModel(entryId: "e1", cashflowRepository: cashflow, money: money, actorId: "u1",
                                       loadAccounts: { accounts }), money)
    }

    private let cashAccount = Account(id: "acc-cash", name: "Cash", type: .cash, currentBalance: 0)
    private let bankAccount = Account(id: "acc-bank", name: "HDFC", type: .bank, currentBalance: 0)

    @Test func loadFillsTheFormFromTheEntry() async {
        let (model, _) = makeSUT([entry()])
        await model.load()
        #expect(model.isLoaded)
        #expect(model.isIn)
        #expect(model.selectedAccountId == CashflowTransaction.PaymentMode.cash.accountId)
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

    @Test func cashOutComesFromTheChosenAccountAndCashInGoesToIt() async {
        var recorded = entry()
        recorded.toAccountId = "acc-cash"
        let (model, money) = makeSUT([recorded], accounts: [cashAccount, bankAccount])
        await model.load()
        #expect(model.accountTitle == "To account")
        #expect(model.selectedAccountId == "acc-cash")
        model.isIn = false
        #expect(model.accountTitle == "From account")
        model.selectAccount("acc-bank")
        #expect(await model.save())
        let saved = money.updatedEntries.first
        #expect(saved?.transactionType == .debit)
        #expect(saved?.paymentMode == .upi)
        #expect(saved?.fromAccountId == "acc-bank")
        #expect(saved?.toAccountId == "")
    }

    @Test func flippingDirectionKeepsTheSameAccountOnTheOtherSide() async {
        var recorded = entry()
        recorded.toAccountId = "acc-cash"
        let (model, money) = makeSUT([recorded], accounts: [cashAccount, bankAccount])
        await model.load()
        model.isIn = false
        #expect(await model.save())
        #expect(money.updatedEntries.first?.fromAccountId == "acc-cash")
        #expect(money.updatedEntries.first?.toAccountId == "")
        #expect(money.updatedEntries.first?.paymentMode == .cash)
    }

    @Test func anEntryWithoutAnAccountIdPicksTheAccountMatchingItsMode() async {
        var legacy = entry()
        legacy.toAccountId = ""
        legacy.fromAccountId = ""
        let (model, money) = makeSUT([legacy], accounts: [bankAccount, cashAccount])
        await model.load()
        #expect(model.selectedAccountId == "acc-cash")
        model.particulars = "Tea"
        #expect(await model.save())
        // Nothing about the account changed, so the blank ids are left as they were.
        #expect(money.updatedEntries.first?.toAccountId == "")
        #expect(money.updatedEntries.first?.fromAccountId == "")
    }

    @Test func anAccountNotInTheOrganizationStaysSelectable() async {
        var recorded = entry()
        recorded.toAccountId = "old-account"
        let (model, _) = makeSUT([recorded], accounts: [cashAccount])
        await model.load()
        #expect(model.selectedAccountId == "old-account")
        #expect(model.accounts.map(\.id) == ["acc-cash", "old-account"])
        model.selectAccount("nope")
        #expect(model.selectedAccountId == "old-account")
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

    @Test func categoryAndSubCategoryLoadAndStayUntouchedUnlessChanged() async {
        var legacy = entry()
        legacy.category = .unknown          // a category string this app didn't recognise when it decoded
        legacy.subCategory = .unknown
        let (model, money) = makeSUT([legacy])
        await model.load()
        #expect(model.category == .unknown)
        #expect(model.categories.contains(.unknown))
        model.particulars = "Float"
        #expect(await model.save())
        #expect(money.updatedEntries.first?.category == .unknown)
        #expect(money.updatedEntries.first?.subCategory == .unknown)
    }

    @Test func changingTheCategoryPicksItsFirstSubCategoryAndIsSaved() async {
        let (model, money) = makeSUT([entry()])
        await model.load()
        model.selectCategory(.utilities)
        #expect(model.subCategory == .electricity)
        model.selectSubCategory(.water)
        #expect(await model.save())
        #expect(money.updatedEntries.first?.category == .utilities)
        #expect(money.updatedEntries.first?.subCategory == .water)
    }

    @Test func categoryPathSkipsUnknownAndDuplicateParts() {
        var utility = entry(type: .debit)
        utility.category = .utilities
        utility.subCategory = .rent
        #expect(utility.categoryPath == "Utilities › Rent")
        var sameName = entry()
        sameName.category = .salesRevenue
        sameName.subCategory = .salesRevenue
        #expect(sameName.categoryPath == "Sales Revenue")
        var unknown = entry()
        unknown.category = .unknown
        unknown.subCategory = .unknown
        #expect(unknown.categoryPath == nil)
    }

    @Test func rowTitleIsTheSubCategoryWithCategoryAccountTimeAndNoteBelow() {
        let drawer = Account(id: CashflowTransaction.PaymentMode.cash.accountId, name: "Cash drawer", type: .cash, currentBalance: 0)
        var rent = entry(type: .debit)
        rent.category = .utilities
        rent.subCategory = .rent
        rent.particulars = "Rent · shop lease"
        #expect(rent.rowTitle == "Rent")
        #expect(rent.noteText == "shop lease")
        let subtitle = rent.rowSubtitle(accounts: [drawer])
        #expect(subtitle.hasPrefix("Utilities · Cash drawer · "))
        #expect(subtitle.hasSuffix(" · shop lease"))
    }

    @Test func theNoteIsOptionalSoNoParticularsAndGeneratedLabelsAreNotShownAsNotes() {
        var noNote = entry()
        noNote.category = .inventory
        noNote.subCategory = .readyStock
        for text in ["No particulars", "", "  ", "Ready Stock", "Inventory", "Cash in"] {
            noNote.particulars = text
            #expect(noNote.noteText == nil)
        }
        #expect(!noNote.rowSubtitle(accounts: []).contains("No particulars"))
        // A legacy free-text description is still shown, under its sub-category.
        noNote.particulars = "Shop flowers decoration"
        #expect(noNote.noteText == "Shop flowers decoration")
        #expect(noNote.rowSubtitle(accounts: []).hasSuffix(" · Shop flowers decoration"))
    }

    @Test func rowTitleFallsBackToCategoryThenNote() {
        var onlyCategory = entry()
        onlyCategory.category = .utilities
        onlyCategory.subCategory = .unknown
        #expect(onlyCategory.rowTitle == "Utilities")
        #expect(!onlyCategory.rowSubtitle(accounts: []).hasPrefix("Utilities ·"))   // not repeated as the category
        var neither = entry()
        neither.category = .unknown
        neither.subCategory = nil
        neither.particulars = "Float from owner"
        #expect(neither.rowTitle == "Float from owner")
        neither.particulars = "No particulars"
        #expect(neither.rowTitle == "Entry")
    }

    @Test func accountNameFollowsTheDirectionAndFallsBackToTheMode() {
        let cash = Account(id: "acc-cash", name: "Cash", type: .cash, currentBalance: 0)
        let bank = Account(id: "acc-bank", name: "HDFC", type: .bank, currentBalance: 0)
        var cashIn = entry()
        cashIn.toAccountId = "acc-bank"
        // The category is the title here (no sub-category), so the subtitle starts with the account.
        #expect(cashIn.rowSubtitle(accounts: [cash, bank]).hasPrefix("HDFC · "))
        var cashOut = entry(type: .debit)
        cashOut.fromAccountId = "acc-cash"
        #expect(cashOut.rowSubtitle(accounts: [cash, bank]).hasPrefix("Cash · "))
        // No ids and no accounts: name the mode.
        var legacy = entry(mode: .upi)
        legacy.toAccountId = ""
        legacy.fromAccountId = ""
        #expect(legacy.rowSubtitle(accounts: []).hasPrefix("Bank · "))
        legacy.paymentMode = .cash
        #expect(legacy.rowSubtitle(accounts: []).hasPrefix("Cash · "))
    }

    @Test func aTransferRowShowsFromToAndItsNoteOnly() {
        let cash = Account(id: "acc-cash", name: "Cash", type: .cash, currentBalance: 0)
        let bank = Account(id: "acc-bank", name: "HDFC", type: .bank, currentBalance: 0)
        var transfer = entry(type: .debit)
        transfer.category = .internalTransfer
        transfer.subCategory = .internalTransfer
        transfer.fromAccountId = "acc-cash"
        transfer.toAccountId = "acc-bank"
        transfer.particulars = "Transfer Cash → HDFC · deposit"
        #expect(transfer.rowTitle == "Internal Transfer")
        #expect(transfer.noteText == "deposit")
        let subtitle = transfer.rowSubtitle(accounts: [cash, bank])
        #expect(subtitle.hasPrefix("Cash → HDFC · "))
        #expect(subtitle.hasSuffix(" · deposit"))
        transfer.particulars = "Transfer Cash → HDFC"
        #expect(transfer.noteText == nil)
    }

    @Test func deleteSoftDeletesTheOriginalEntry() async {
        let (model, money) = makeSUT([entry()])
        await model.load()
        #expect(await model.delete())
        #expect(money.deletedEntries.map(\.id) == ["e1"])
    }
}

@MainActor
struct CashTransferTests {
    private let cash = Account(id: "acc-cash", name: "Cash", type: .cash, currentBalance: 0)
    private let bank = Account(id: "acc-bank", name: "HDFC", type: .bank, currentBalance: 0)
    private let upi = Account(id: "acc-upi", name: "UPI", type: .upi, currentBalance: 0)

    private func transfer(from: String, to: String, amount: Double = 500, id: String = "t1") -> CashflowTransaction {
        CashflowTransaction(id: id, timestamp: Date(), particulars: "Transfer", amount: amount, transactionType: .debit, paymentMode: .cash,
                            category: .internalTransfer, subCategory: .internalTransfer, fromAccountId: from, toAccountId: to,
                            timestampInMs: 0, updatedAtInMs: 0)
    }

    // MARK: Cash drawer maths

    @Test func aTransferOutOfCashLowersCashAndIntoCashRaisesIt() {
        let ids: Set<String> = ["acc-cash"]
        #expect(transfer(from: "acc-cash", to: "acc-bank").cashEffect(cashAccountIds: ids) == -500)
        #expect(transfer(from: "acc-bank", to: "acc-cash").cashEffect(cashAccountIds: ids) == 500)
        #expect(transfer(from: "acc-bank", to: "acc-upi").cashEffect(cashAccountIds: ids) == 0)
        #expect(transfer(from: "acc-cash", to: "acc-cash").cashEffect(cashAccountIds: ids) == 0)
    }

    @Test func olderSingleSidedTransferEntriesStillCount() {
        let ids: Set<String> = ["acc-cash"]
        #expect(transfer(from: "acc-cash", to: "").cashEffect(cashAccountIds: ids) == -500)
        #expect(transfer(from: "", to: "acc-cash").cashEffect(cashAccountIds: ids) == 500)
        // No account ids at all: fall back to payment mode and direction like any other entry.
        #expect(transfer(from: "", to: "").cashEffect(cashAccountIds: ids) == -500)
    }

    @Test func cashDayCountsATransferByItsAccounts() {
        let entries = [transfer(from: "acc-cash", to: "acc-bank", amount: 300, id: "a"),
                       transfer(from: "acc-bank", to: "acc-cash", amount: 100, id: "b"),
                       transfer(from: "acc-bank", to: "acc-upi", amount: 999, id: "c")]
        let day = CashDay(date: Date(), summaries: [], sales: [], transactions: entries, cashAccountIds: ["acc-cash"])
        #expect(day.cashOut == 300)
        #expect(day.cashIn == 100)
        #expect(day.expectedClosing == -200)
    }

    @Test func isTransferNeedsBothAccountIds() {
        #expect(transfer(from: "a", to: "b").isTransfer)
        #expect(!transfer(from: "a", to: "").isTransfer)
        var plain = transfer(from: "a", to: "b")
        plain.category = .miscellaneous
        #expect(!plain.isTransfer)
    }

    // MARK: Add

    @Test func transferDefaultsToFromCashAndToAnotherAccount() async {
        let model = CashEntryViewModel(money: RecordingMoney(), actorId: "u1", loadAccounts: { [bank, cash] })
        await model.load()
        model.setKind(.transfer)
        #expect(model.isTransfer)
        #expect(model.category == .internalTransfer)
        #expect(model.fromAccountId == "acc-cash")
        #expect(model.toAccountId == "acc-bank")
    }

    @Test func pickingTheSameAccountOnBothSidesMovesTheOtherOne() async {
        let model = CashEntryViewModel(money: RecordingMoney(), actorId: "u1", loadAccounts: { [cash, bank, upi] })
        await model.load()
        model.setKind(.transfer)
        model.selectToAccount("acc-cash")
        #expect(model.toAccountId == "acc-cash")
        #expect(model.fromAccountId != "acc-cash")
        model.selectFromAccount("acc-cash")
        #expect(model.fromAccountId == "acc-cash")
        #expect(model.toAccountId != "acc-cash")
        model.selectFromAccount("nope")           // unknown ids are ignored
        #expect(model.fromAccountId == "acc-cash")
    }

    @Test func aTransferSavesOneEntryNotTwo() async {
        let money = RecordingMoney()
        let model = CashEntryViewModel(money: money, actorId: "u1", loadAccounts: { [cash, bank] })
        await model.load()
        model.setKind(.transfer)
        #expect(!model.canSave)                    // no amount yet
        model.amountText = "500"
        model.note = "deposit"
        #expect(model.particulars == "Transfer Cash → HDFC · deposit")
        #expect(await model.save())
        #expect(money.transfers.count == 1)
        #expect(money.transfers.first?.from.id == "acc-cash")
        #expect(money.transfers.first?.to.id == "acc-bank")
        #expect(money.cashEntries.isEmpty)         // not also recorded as a cash in or out
    }

    @Test func aTransferNeedsTwoAccounts() async {
        let money = RecordingMoney()
        let model = CashEntryViewModel(money: money, actorId: "u1", loadAccounts: { [cash] })
        await model.load()
        model.setKind(.transfer)
        model.amountText = "100"
        #expect(model.transferNeedsMoreAccounts)
        #expect(!model.canSave)
        #expect(await model.save() == false)
        #expect(money.transfers.isEmpty)
    }

    @Test func aRetriedTransferReusesItsId() async {
        let money = RecordingMoney()
        let model = CashEntryViewModel(money: money, actorId: "u1", loadAccounts: { [cash, bank] })
        await model.load()
        model.setKind(.transfer)
        model.amountText = "500"
        money.fail = true
        #expect(await model.save() == false)
        money.fail = false
        #expect(await model.save())
        #expect(money.transferIds.count == 2)
        #expect(money.transferIds[0] == money.transferIds[1])
        #expect(await model.save())                // the next transfer is a new entry
        #expect(money.transferIds[2] != money.transferIds[1])
    }

    @Test func shopSetupIsNotOffered() async {
        let model = CashEntryViewModel(money: RecordingMoney(), actorId: "u1")
        #expect(!model.categories.contains(.shopSetup))
    }

    @Test func switchingBackToCashInOrOutRestoresTheCategories() async {
        let model = CashEntryViewModel(money: RecordingMoney(), actorId: "u1", loadAccounts: { [cash, bank] })
        await model.load()
        model.setKind(.transfer)
        model.setKind(.cashIn)
        #expect(model.category == .salesRevenue)
        #expect(!model.isTransfer)
        model.setKind(.cashOut)
        #expect(model.category == .miscellaneous)
        #expect(CashEntryViewModel.Kind.allCases.map(\.title) == ["Cash in", "Cash out", "Internal transfer"])
    }

    // MARK: Edit

    private func editSUT(_ entry: CashflowTransaction, accounts: [Account]) -> (CashEntryEditViewModel, RecordingMoney) {
        let repo = FixedCashflowRepository()
        repo.items = [entry]
        let money = RecordingMoney()
        return (CashEntryEditViewModel(entryId: entry.id, cashflowRepository: repo, money: money, actorId: "u1",
                                       loadAccounts: { accounts }), money)
    }

    @Test func editingATransferShowsBothAccountsAndKeepsItsCategory() async {
        let (model, money) = editSUT(transfer(from: "acc-cash", to: "acc-bank"), accounts: [cash, bank, upi])
        await model.load()
        #expect(model.isTransfer)
        #expect(model.fromAccountId == "acc-cash")
        #expect(model.toAccountId == "acc-bank")
        model.amountText = "450"
        #expect(await model.save())
        let saved = money.updatedEntries.first
        #expect(saved?.amount == 450)
        #expect(saved?.category == .internalTransfer)
        #expect(saved?.fromAccountId == "acc-cash")      // untouched accounts stay as they were
        #expect(saved?.toAccountId == "acc-bank")
        #expect(saved?.transactionType == .debit)
    }

    @Test func changingATransfersAccountsRewritesBothIds() async {
        let (model, money) = editSUT(transfer(from: "acc-cash", to: "acc-bank"), accounts: [cash, bank, upi])
        await model.load()
        model.selectFromAccount("acc-bank")
        model.selectToAccount("acc-upi")
        #expect(await model.save())
        let saved = money.updatedEntries.first
        #expect(saved?.fromAccountId == "acc-bank")
        #expect(saved?.toAccountId == "acc-upi")
        #expect(saved?.paymentMode == .upi)               // the source is now a bank account
    }

    @Test func aTransferCannotBeSavedWithTheSameAccountOnBothSides() async {
        let (model, _) = editSUT(transfer(from: "acc-cash", to: "acc-bank"), accounts: [cash, bank])
        await model.load()
        model.selectToAccount("acc-cash")                 // swaps the source away from cash
        #expect(model.fromAccountId != model.toAccountId)
        #expect(model.canSave)
    }

    @Test func aOneSidedLegacyTransferEditsLikeAnOrdinaryEntry() async {
        let (model, _) = editSUT(transfer(from: "acc-cash", to: ""), accounts: [cash, bank])
        await model.load()
        #expect(!model.isTransfer)
        #expect(model.selectedAccountId == "acc-cash")
        #expect(model.categories.contains(.internalTransfer))   // its own category stays visible
    }
}
