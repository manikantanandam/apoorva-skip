//
//  MoneyViewModels.swift
//  ApoorvaModules
//
//  Cashflow day (83), cash entry (84), close day (85), history (86), expenses (87, 88),
//  today's summary (89).
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

extension Sale {
    /// Signed amount paid by a mode: returns count against the day.
    func paid(_ mode: PaymentMode) -> Double {
        let amount = payments[mode] ?? 0
        return isReturn ? -amount : amount
    }

    var signedTotal: Double { isReturn ? -netPayable : netPayable }
}

/// Cash drawer maths for one day, shared by the day screen, close and summary.
public struct CashDay: Sendable {
    public let date: Date
    public let opening: Double
    public let cashSales: Double
    public let cashIn: Double
    public let cashOut: Double
    public let byMode: [PaymentMode: Double]
    public let entries: [CashflowTransaction]

    public init(date: Date, summaries: [DailyCashflowSummary], sales: [Sale], transactions: [CashflowTransaction]) {
        let calendar = Calendar.current
        self.date = calendar.startOfDay(for: date)
        let cashAccount = CashflowTransaction.PaymentMode.cash.accountId
        let today = summaries.first { $0.id == date.dayKey }
        let previous = summaries.filter { $0.date < calendar.startOfDay(for: date) }.sorted { $0.date > $1.date }.first
        // Opening: today's recorded opening, else yesterday's closing cash.
        if let opening = today?.openingBalances.first(where: { $0.id == cashAccount })?.balance {
            self.opening = opening
        } else {
            self.opening = previous?.closingBalances.first(where: { $0.id == cashAccount })?.balance ?? 0
        }
        let daySales = sales.filter { !$0.isCancelled && calendar.isDate($0.timestamp, inSameDayAs: date) }
        cashSales = daySales.reduce(0) { $0 + $1.paid(.cash) }
        var modes: [PaymentMode: Double] = [:]
        for sale in daySales {
            for mode in PaymentMode.allCases where mode != .credit {
                modes[mode, default: 0] += sale.paid(mode)
            }
        }
        byMode = modes
        entries = transactions.filter { !$0.isDeleted && calendar.isDate($0.timestamp, inSameDayAs: date) && $0.category != .shopSetup }
            .sorted { $0.timestamp > $1.timestamp }
        let cashEntries = entries.filter { $0.paymentMode == .cash }
        cashIn = cashSales + cashEntries.filter { $0.transactionType == .credit }.reduce(0) { $0 + $1.amount }
        cashOut = cashEntries.filter { $0.transactionType == .debit }.reduce(0) { $0 + $1.amount }
    }

    public var expectedClosing: Double { opening + cashIn - cashOut }
}

// MARK: - Day (83)

@MainActor
@Observable
public final class CashDayViewModel {
    public var date: Date
    public private(set) var day: CashDay?
    public private(set) var close: DayClose?

    private let summaries: DailyCashflowSummaryRepositoryProtocol
    private let saleRepository: SaleRepositoryProtocol
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    private let dayCloses: any OrgCollectionRepositoryProtocol<DayClose>

    public init(date: Date = Date(), summaries: DailyCashflowSummaryRepositoryProtocol, saleRepository: SaleRepositoryProtocol,
                cashflowRepository: CashflowTransactionRepositoryProtocol, dayCloses: any OrgCollectionRepositoryProtocol<DayClose>) {
        self.date = date
        self.summaries = summaries
        self.saleRepository = saleRepository
        self.cashflowRepository = cashflowRepository
        self.dayCloses = dayCloses
    }

    public func load() async {
        day = CashDay(date: date, summaries: (try? await summaries.getDailyCashflowSummaries()) ?? [],
                      sales: (try? await saleRepository.getSales()) ?? [],
                      transactions: (try? await cashflowRepository.getCashflowTransactions()) ?? [])
        close = (try? await dayCloses.get(id: date.dayKey)).flatMap { $0?.isDeleted == false ? $0 : nil }
    }

    public var isClosed: Bool { close != nil }
    public var isToday: Bool { Calendar.current.isDateInToday(date) }

    public func step(_ days: Int) async {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: date), next <= Date() else { return }
        date = next
        await load()
    }
}

// MARK: - Cash entry (84)

@MainActor
@Observable
public final class CashEntryViewModel {
    public enum Purpose: String, CaseIterable, Sendable {
        case supplier = "Supplier", rent = "Rent", salary = "Salary", tea = "Tea & snacks", other = "Other"

        var category: ExpenseCategory {
            switch self {
            case .supplier: .supplier
            case .rent: .rent
            case .salary: .salary
            case .tea: .tea
            case .other: .other
            }
        }

        var title: String {
            switch self {
            case .supplier: "Supplier payment"
            default: rawValue
            }
        }
    }

    public var isIn = false
    public var amountText = ""
    public var purpose: Purpose = .supplier
    public var note = ""
    public var errorMessage: String?

    private let money: MoneyRepositoryProtocol
    private let actorId: String

    public init(money: MoneyRepositoryProtocol, actorId: String) {
        self.money = money
        self.actorId = actorId
    }

    public var amount: Double { Double(amountText) ?? 0 }
    public var particulars: String {
        let base = isIn ? "Cash in" : purpose.title
        return note.isEmpty ? base : "\(base) · \(note)"
    }

    public func save() async -> Bool {
        guard amount > 0 else { return false }
        do {
            try await money.addCashEntry(isIn: isIn, amount: amount, category: isIn ? nil : purpose.category, particulars: particulars, by: actorId)
            return true
        } catch {
            errorMessage = "Couldn't save the entry."
            return false
        }
    }
}

// MARK: - Close day (85)

@MainActor
@Observable
public final class DayCloseViewModel {
    public let date: Date
    public private(set) var expected: Double = 0
    public var countedText = ""
    public var note = ""
    public var carryForward = true
    public var isSaving = false
    public var errorMessage: String?

    private let dayViewModel: CashDayViewModel
    private let money: MoneyRepositoryProtocol
    private let actorId: String
    private let actorName: String

    public init(date: Date, dayViewModel: CashDayViewModel, money: MoneyRepositoryProtocol, actorId: String, actorName: String) {
        self.date = date
        self.dayViewModel = dayViewModel
        self.money = money
        self.actorId = actorId
        self.actorName = actorName
    }

    public func load() async {
        await dayViewModel.load()
        expected = dayViewModel.day?.expectedClosing ?? 0
        if countedText.isEmpty { countedText = String(Int(expected.rounded())) }
    }

    public var counted: Double { Double(countedText) ?? 0 }
    public var difference: Double { counted - expected }
    public var tomorrow: Date { Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date }

    public func close() async -> Bool {
        guard !countedText.isEmpty else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await money.closeDay(DayClose(date: date, expectedCash: expected, countedCash: counted, note: note,
                                              carryForward: carryForward, closedBy: actorId, closedByName: actorName))
            return true
        } catch {
            errorMessage = "Couldn't close the day. Try again."
            return false
        }
    }
}

// MARK: - History (86)

@MainActor
@Observable
public final class CashHistoryViewModel {
    public struct Row: Identifiable, Sendable {
        public var id: String { date.dayKey }
        public let date: Date
        public let close: DayClose?
        public let hadSales: Bool
    }

    public var month = Date()
    public private(set) var rows: [Row] = []

    private let dayCloses: any OrgCollectionRepositoryProtocol<DayClose>
    private let saleRepository: SaleRepositoryProtocol
    private let money: MoneyRepositoryProtocol
    private let actorId: String

    public init(dayCloses: any OrgCollectionRepositoryProtocol<DayClose>, saleRepository: SaleRepositoryProtocol,
                money: MoneyRepositoryProtocol, actorId: String) {
        self.dayCloses = dayCloses
        self.saleRepository = saleRepository
        self.money = money
        self.actorId = actorId
    }

    /// Every day of the month up to today, newest first.
    public func load() async {
        let calendar = Calendar.current
        let closes = ((try? await dayCloses.all()) ?? []).filter { !$0.isDeleted }
        let saleDays = Set(((try? await saleRepository.getSales()) ?? []).map { $0.timestamp.dayKey })
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return }
        var days: [Row] = []
        var day = interval.start
        let today = calendar.startOfDay(for: Date())
        while day < interval.end && day <= today {
            days.append(Row(date: day, close: closes.first { $0.id == day.dayKey }, hadSales: saleDays.contains(day.dayKey)))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        rows = days.reversed()
    }

    public var title: String { month.formatted(.dateTime.month(.wide).year()) }

    public func reopen(_ row: Row) async {
        try? await money.reopenDay(row.date, by: actorId)
        await load()
    }

    public func step(_ months: Int) async {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: month), next <= Date() else { return }
        month = next
        await load()
    }

    public var csv: String {
        var lines = ["Date,Expected,Counted,Difference,Closed by,Note"]
        for row in rows {
            if let close = row.close {
                lines.append("\(row.date.dayKey),\(Int(close.expectedCash)),\(Int(close.countedCash)),\(Int(close.difference)),\(close.closedByName),\"\(close.note)\"")
            } else {
                lines.append("\(row.date.dayKey),,,,\(row.hadSales ? "Not closed" : "Shop closed"),")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Expenses (87, 88)

@MainActor
@Observable
public final class ExpensesViewModel {
    public var month = Date()
    public private(set) var expenses: [Expense] = []

    private let repository: any OrgCollectionRepositoryProtocol<Expense>

    public init(repository: any OrgCollectionRepositoryProtocol<Expense>) {
        self.repository = repository
    }

    public func load() async {
        let all = ((try? await repository.all()) ?? []).filter { !$0.isDeleted }
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return }
        expenses = all.filter { interval.contains($0.date) }.sorted { $0.date > $1.date }
    }

    public var total: Double { expenses.reduce(0) { $0 + $1.amount } }

    /// Category shares for the split bar, largest first; small ones fold into Other.
    public var byCategory: [(category: ExpenseCategory, amount: Double)] {
        Dictionary(grouping: expenses, by: \.category).map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }

    public var title: String { "\(month.formatted(.dateTime.month(.wide))) · \(Money.format(total))" }

    public func step(_ months: Int) async {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: month), next <= Date() else { return }
        month = next
        await load()
    }
}

@MainActor
@Observable
public final class ExpenseFormViewModel {
    public let expenseId: String?
    public var amountText = ""
    public var title = ""
    public var category: ExpenseCategory = .electricity
    public var mode = "cash"
    public var date = Date()
    public var repeatsMonthly = false
    public var errorMessage: String?

    private var original: Expense?
    private let repository: any OrgCollectionRepositoryProtocol<Expense>
    private let money: MoneyRepositoryProtocol
    private let actorId: String

    public init(expenseId: String?, repository: any OrgCollectionRepositoryProtocol<Expense>, money: MoneyRepositoryProtocol, actorId: String) {
        self.expenseId = expenseId
        self.repository = repository
        self.money = money
        self.actorId = actorId
    }

    public func load() async {
        guard let expenseId, let expense = try? await repository.get(id: expenseId) else { return }
        original = expense
        amountText = String(Int(expense.amount))
        title = expense.title
        category = expense.category
        mode = expense.mode
        date = expense.date
        repeatsMonthly = expense.repeatsMonthly
    }

    public var amount: Double { Double(amountText) ?? 0 }
    public var displayTitle: String { title.isEmpty ? "\(category.title) bill" : title }
    public var canSave: Bool { amount > 0 }

    public func save() async -> Bool {
        guard canSave else { return false }
        var expense = original ?? Expense(title: displayTitle, category: category, amount: amount, createdBy: actorId)
        expense.title = displayTitle
        expense.category = category
        expense.amount = amount
        expense.mode = mode
        expense.date = date
        expense.repeatsMonthly = repeatsMonthly
        expense.updatedAt = Date()
        do {
            try await money.saveExpense(expense)
            return true
        } catch {
            errorMessage = "Couldn't save the expense."
            return false
        }
    }
}

// MARK: - Today's summary (89)

@MainActor
@Observable
public final class DailySummaryViewModel {
    public let date: Date
    public private(set) var sales: Double = 0
    public private(set) var bills = 0
    public private(set) var profit: Double = 0
    public private(set) var byMode: [PaymentMode: Double] = [:]
    public private(set) var duesCollected: Double = 0
    public private(set) var newCredit: Double = 0
    public private(set) var expenses: Double = 0
    public private(set) var topItem: String?
    public private(set) var isClosed = false

    private let saleRepository: SaleRepositoryProtocol
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let ledger: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>
    private let expenseRepository: any OrgCollectionRepositoryProtocol<Expense>
    private let dayCloses: any OrgCollectionRepositoryProtocol<DayClose>
    private let shopName: String

    public init(date: Date = Date(), saleRepository: SaleRepositoryProtocol, inventoryRepository: InventoryItemRepositoryProtocol,
                ledger: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>, expenseRepository: any OrgCollectionRepositoryProtocol<Expense>,
                dayCloses: any OrgCollectionRepositoryProtocol<DayClose>, shopName: String) {
        self.date = date
        self.saleRepository = saleRepository
        self.inventoryRepository = inventoryRepository
        self.ledger = ledger
        self.expenseRepository = expenseRepository
        self.dayCloses = dayCloses
        self.shopName = shopName
    }

    public func load() async {
        let calendar = Calendar.current
        let daySales = ((try? await saleRepository.getSales()) ?? []).filter { !$0.isCancelled && calendar.isDate($0.timestamp, inSameDayAs: date) }
        let items = (try? await inventoryRepository.getInventoryItems()) ?? []
        let dayExpenses = ((try? await expenseRepository.all()) ?? []).filter { !$0.isDeleted && calendar.isDate($0.date, inSameDayAs: date) }
        let entries = ((try? await ledger.all()) ?? []).filter { !$0.isDeleted && calendar.isDate($0.createdAt, inSameDayAs: date) }
        let metrics = ShopMetrics(sales: daySales, items: items, expenses: dayExpenses)
        sales = metrics.revenue
        bills = metrics.billCount
        expenses = metrics.expenseTotal
        profit = metrics.netProfit
        byMode = metrics.byMode
        topItem = metrics.topItems.first?.name
        duesCollected = entries.filter { $0.kind == .payment }.reduce(0) { $0 - $1.amount }
        newCredit = entries.filter { $0.kind == .sale }.reduce(0) { $0 + $1.amount }
        isClosed = (try? await dayCloses.get(id: date.dayKey))??.isDeleted == false
    }

    public var shareText: String {
        var lines = ["*\(shopName)* · \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))",
                     "Sales: \(Money.format(sales)) (\(bills) bills)",
                     "Profit (est.): \(Money.format(profit))"]
        for mode in [PaymentMode.cash, .upi, .card] where (byMode[mode] ?? 0) != 0 {
            lines.append("\(mode.title): \(Money.format(byMode[mode] ?? 0))")
        }
        lines.append("Dues collected: \(Money.format(duesCollected))")
        lines.append("New credit: \(Money.format(newCredit))")
        lines.append("Expenses: \(Money.format(expenses))")
        if let topItem { lines.append("Top item: \(topItem)") }
        return lines.joined(separator: "\n")
    }
}
