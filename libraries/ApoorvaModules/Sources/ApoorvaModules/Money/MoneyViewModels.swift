//
//  MoneyViewModels.swift
//  ApoorvaModules
//
//  Cashflow day (83), cash entry (84), close day (85), history (86), expenses (87, 88),
//  today's summary (89).
//

import Foundation
import Observation
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

extension CashflowTransaction {
    /// A transfer between two of the organization's accounts, saved as one entry with both account ids.
    var isTransfer: Bool { category == .internalTransfer && !fromAccountId.isEmpty && !toAccountId.isEmpty }

    /// Effect on the cash drawer: positive when money enters cash, negative when it leaves, zero otherwise.
    /// Transfers (and older single-sided transfer entries that carry an account id) are judged by whether their
    /// account is a cash account; every other entry by its payment mode and direction.
    func cashEffect(cashAccountIds: Set<String>) -> Double {
        if category == .internalTransfer && (!fromAccountId.isEmpty || !toAccountId.isEmpty) {
            return (cashAccountIds.contains(toAccountId) ? amount : 0) - (cashAccountIds.contains(fromAccountId) ? amount : 0)
        }
        guard paymentMode == .cash else { return 0 }
        switch transactionType {
        case .credit: return amount
        case .debit: return -amount
        case .unknown: return 0
        }
    }
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

    public init(date: Date, summaries: [DailyCashflowSummary], sales: [Sale], transactions: [CashflowTransaction],
                cashAccountIds: Set<String> = [CashflowTransaction.PaymentMode.cash.accountId]) {
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
        let effects = entries.map { $0.cashEffect(cashAccountIds: cashAccountIds) }
        cashIn = cashSales + effects.filter { $0 > 0 }.reduce(0, +)
        cashOut = effects.filter { $0 < 0 }.reduce(0) { $0 - $1 }
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
    /// `dayKey`s of days whose closing balance is saved: a day close from this app, or a legacy daily summary that
    /// has closing balances. The calendar marks these green.
    public private(set) var closedDayKeys: Set<String> = []

    private let summaries: DailyCashflowSummaryRepositoryProtocol
    private let saleRepository: SaleRepositoryProtocol
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    private let dayCloses: any OrgCollectionRepositoryProtocol<DayClose>
    private let loadAccounts: @Sendable () async -> [Account]

    public init(date: Date = Date(), summaries: DailyCashflowSummaryRepositoryProtocol, saleRepository: SaleRepositoryProtocol,
                cashflowRepository: CashflowTransactionRepositoryProtocol, dayCloses: any OrgCollectionRepositoryProtocol<DayClose>,
                loadAccounts: @escaping @Sendable () async -> [Account] = { [] }) {
        self.date = date
        self.summaries = summaries
        self.saleRepository = saleRepository
        self.cashflowRepository = cashflowRepository
        self.dayCloses = dayCloses
        self.loadAccounts = loadAccounts
    }

    public func load() async {
        let allSummaries = (try? await summaries.getDailyCashflowSummaries()) ?? []
        // Transfers move money by account id, so the day needs to know which accounts are cash. The fixed legacy
        // cash id stays included for organizations whose accounts use it.
        let cashAccountIds = Set(await loadAccounts().filter { $0.type == .cash && !$0.isDeleted }.map(\.id))
            .union([CashflowTransaction.PaymentMode.cash.accountId])
        day = CashDay(date: date, summaries: allSummaries,
                      sales: (try? await saleRepository.getSales()) ?? [],
                      transactions: (try? await cashflowRepository.getCashflowTransactions()) ?? [],
                      cashAccountIds: cashAccountIds)
        let closes = ((try? await dayCloses.all()) ?? []).filter { !$0.isDeleted }
        close = closes.first { $0.id == date.dayKey }
        closedDayKeys = Set(closes.map(\.id))
            .union(allSummaries.filter { !$0.closingBalances.isEmpty }.map(\.id))
    }

    public var isClosed: Bool { close != nil }
    public var isToday: Bool { Calendar.current.isDateInToday(date) }

    /// Jumps to a day picked in the calendar. Future days are ignored.
    public func go(to target: Date) async {
        let calendar = Calendar.current
        guard calendar.startOfDay(for: target) <= calendar.startOfDay(for: Date()) else { return }
        date = target
        await load()
    }

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
    /// What the entry is: money in, money out, or a transfer between two of the organization's accounts.
    public enum Kind: String, CaseIterable, Sendable {
        case cashIn, cashOut, transfer

        public var title: String {
            switch self {
            case .cashIn: "Cash in"
            case .cashOut: "Cash out"
            case .transfer: "Internal transfer"
            }
        }
    }

    public private(set) var kind: Kind = .cashOut
    public var isIn: Bool { kind == .cashIn }
    public var isTransfer: Bool { kind == .transfer }
    public var amountText = ""
    public private(set) var category: CashflowCategory = .miscellaneous
    public private(set) var subCategory: CashflowSubCategory = .general
    public var note = ""
    public var errorMessage: String?
    /// The organization's accounts. Empty until loaded, or if they can't be read (the cash account is used then).
    public private(set) var accounts: [Account] = []
    public private(set) var selectedAccountId: String?
    /// For a transfer: the account the money leaves and the account it goes to. Always different.
    public private(set) var fromAccountId: String?
    public private(set) var toAccountId: String?

    private let money: MoneyRepositoryProtocol
    private let actorId: String
    private let loadAccounts: @Sendable () async -> [Account]

    public init(money: MoneyRepositoryProtocol, actorId: String, loadAccounts: @escaping @Sendable () async -> [Account] = { [] }) {
        self.money = money
        self.actorId = actorId
        self.loadAccounts = loadAccounts
    }

    /// Cash in goes to an account, cash out comes from one.
    public var accountTitle: String { isIn ? "To account" : "From account" }
    public var selectedAccount: Account? { accounts.first { $0.id == selectedAccountId } }
    public var fromAccount: Account? { accounts.first { $0.id == fromAccountId } }
    public var toAccount: Account? { accounts.first { $0.id == toAccountId } }
    /// A transfer needs two accounts to move money between.
    public var transferNeedsMoreAccounts: Bool { isTransfer && accounts.count < 2 }

    public func load() async {
        accounts = await loadAccounts().filter { !$0.isDeleted }
        if selectedAccount == nil {
            selectedAccountId = (accounts.first { $0.type == .cash } ?? accounts.first)?.id
        }
        if fromAccount == nil { fromAccountId = selectedAccountId }
        if toAccount == nil || toAccountId == fromAccountId { toAccountId = accounts.first { $0.id != fromAccountId }?.id }
    }

    public func selectAccount(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        selectedAccountId = id
    }

    public func selectFromAccount(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        fromAccountId = id
        if toAccountId == id { toAccountId = accounts.first { $0.id != id }?.id }
    }

    public func selectToAccount(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        toAccountId = id
        if fromAccountId == id { fromAccountId = accounts.first { $0.id != id }?.id }
    }

    public var categories: [CashflowCategory] { CashflowCategory.selectable }
    public var subCategories: [CashflowSubCategory] { category.subCategories }

    public func setKind(_ kind: Kind) {
        self.kind = kind
        switch kind {
        case .cashIn: selectCategory(.salesRevenue)
        case .cashOut: selectCategory(.miscellaneous)
        case .transfer:
            category = .internalTransfer
            subCategory = .internalTransfer
        }
    }

    /// Cash in defaults to Sales Revenue and cash out to Miscellaneous; the person can change either.
    public func setDirection(_ isIn: Bool) {
        setKind(isIn ? .cashIn : .cashOut)
    }

    /// Picking a category selects its first sub-category, so the pair is always valid.
    public func selectCategory(_ category: CashflowCategory) {
        self.category = category
        subCategory = category.subCategories.first ?? .unknown
    }

    public func selectSubCategory(_ subCategory: CashflowSubCategory) {
        guard category.subCategories.contains(subCategory) else { return }
        self.subCategory = subCategory
    }

    public var amount: Double { Double(amountText) ?? 0 }
    public var particulars: String {
        let base: String
        switch kind {
        case .cashIn: base = "Cash in"
        case .cashOut: base = subCategory == .general ? category.rawValue : subCategory.rawValue
        case .transfer: base = "Transfer \(fromAccount?.name ?? "?") → \(toAccount?.name ?? "?")"
        }
        return note.isEmpty ? base : "\(base) · \(note)"
    }

    public var canSave: Bool {
        guard amount > 0 else { return false }
        guard isTransfer else { return true }
        return fromAccount != nil && toAccount != nil && fromAccountId != toAccountId
    }

    public func save() async -> Bool {
        guard canSave else { return false }
        do {
            if isTransfer, let from = fromAccount, let to = toAccount {
                // One entry for the whole transfer, with both account ids.
                try await money.addTransfer(amount: amount, from: from, to: to, particulars: particulars, by: actorId)
            } else {
                try await money.addCashEntry(isIn: isIn, amount: amount, category: category, subCategory: subCategory,
                                             account: selectedAccount, particulars: particulars, by: actorId)
            }
            return true
        } catch {
            errorMessage = "Couldn't save the entry."
            return false
        }
    }
}

// MARK: - Edit cash entry

/// Edits or soft-deletes one cash book entry from the day screen, including entries made by the legacy app.
/// Keeps the entry's id, date, category and person; only what the user changes is rewritten.
@MainActor
@Observable
public final class CashEntryEditViewModel {
    public var isIn = false
    public var amountText = ""
    public var particulars = ""
    public private(set) var category: CashflowCategory = .unknown
    public private(set) var subCategory: CashflowSubCategory = .unknown
    public private(set) var selectedAccountId: String?
    /// A transfer entry (one entry with both account ids) edits its two accounts instead of a direction.
    public private(set) var isTransfer = false
    public private(set) var fromAccountId: String?
    public private(set) var toAccountId: String?
    public var isSaving = false
    public var errorMessage: String?
    public private(set) var isLoaded = false

    private let entryId: String
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    private let money: MoneyRepositoryProtocol
    private let actorId: String
    private let loadAccounts: @Sendable () async -> [Account]
    private var original: CashflowTransaction?
    private var orgAccounts: [Account] = []
    /// The account the entry had when opened, so an untouched account is never rewritten.
    private var originalAccountId: String?
    private var originalFromId: String?
    private var originalToId: String?

    public init(entryId: String, cashflowRepository: CashflowTransactionRepositoryProtocol,
                money: MoneyRepositoryProtocol, actorId: String, loadAccounts: @escaping @Sendable () async -> [Account] = { [] }) {
        self.entryId = entryId
        self.cashflowRepository = cashflowRepository
        self.money = money
        self.actorId = actorId
        self.loadAccounts = loadAccounts
    }

    /// Cash in goes to an account, cash out comes from one.
    public var accountTitle: String { isIn ? "To account" : "From account" }

    /// The organization's accounts, plus the entry's own account when it isn't one of them (an old or legacy id),
    /// so the current choice stays visible and keepable.
    public var accounts: [Account] {
        let type: AccountType = original?.paymentMode == .cash ? .cash : .bank
        var result = orgAccounts
        for id in [originalAccountId, originalFromId, originalToId].compactMap({ $0 })
        where !result.contains(where: { $0.id == id }) {
            result.append(Account(id: id, name: "Original account", type: type, currentBalance: 0))
        }
        return result
    }

    public func selectAccount(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        selectedAccountId = id
    }

    public func selectFromAccount(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        fromAccountId = id
        if toAccountId == id { toAccountId = accounts.first { $0.id != id }?.id }
    }

    public func selectToAccount(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        toAccountId = id
        if fromAccountId == id { fromAccountId = accounts.first { $0.id != id }?.id }
    }

    public var amount: Double { Double(amountText) ?? 0 }
    public var canSave: Bool {
        guard isLoaded, amount > 0, !isSaving else { return false }
        return !isTransfer || (fromAccountId != nil && toAccountId != nil && fromAccountId != toAccountId)
    }
    public var date: Date? { original?.timestamp }

    public func load() async {
        guard !isLoaded else { return }
        let found = ((try? await cashflowRepository.getCashflowTransactions()) ?? []).first { $0.id == entryId }
        guard let found, !found.isDeleted else {
            errorMessage = "This entry no longer exists."
            return
        }
        original = found
        isIn = found.transactionType == .credit
        amountText = found.amount.rounded() == found.amount ? String(Int(found.amount)) : String(found.amount)
        particulars = found.particulars
        category = found.category
        subCategory = found.subCategory ?? .unknown
        orgAccounts = await loadAccounts().filter { !$0.isDeleted }
        // Entries made without an account id (older ones) fall back to the account matching their mode.
        let recorded = found.transactionType == .credit ? found.toAccountId : found.fromAccountId
        let derived = orgAccounts.first { $0.type == (found.paymentMode == .cash ? .cash : .bank) }?.id
            ?? orgAccounts.first { $0.type == .upi }?.id
        isTransfer = found.isTransfer
        if isTransfer {
            originalFromId = found.fromAccountId
            originalToId = found.toAccountId
            fromAccountId = originalFromId
            toAccountId = originalToId
        } else {
            originalAccountId = recorded.isEmpty ? derived : recorded
            selectedAccountId = originalAccountId
        }
        isLoaded = true
    }

    /// The categories to offer, plus the entry's own when it isn't normally selectable (an unknown or
    /// internal-transfer entry), so what it has now stays visible and keepable.
    public var categories: [CashflowCategory] {
        let selectable = CashflowCategory.selectable
        return selectable.contains(category) ? selectable : selectable + [category]
    }

    public var subCategories: [CashflowSubCategory] {
        let options = category.subCategories
        // The entry's current sub-category stays listed even if this category doesn't normally offer it.
        return options.contains(subCategory) ? options : options + [subCategory]
    }

    public func selectCategory(_ category: CashflowCategory) {
        guard category != self.category else { return }
        self.category = category
        subCategory = category.subCategories.first ?? .unknown
    }

    public func selectSubCategory(_ subCategory: CashflowSubCategory) {
        self.subCategory = subCategory
    }

    /// The entry with the user's changes applied. Account ids are rebuilt only when the direction or account changed.
    func editedEntry() -> CashflowTransaction? {
        guard var edited = original else { return nil }
        edited.amount = amount
        edited.particulars = particulars.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTransfer {
            // A transfer keeps its category and type; only its two accounts (and the mode of the source) can change.
            if fromAccountId != originalFromId || toAccountId != originalToId,
               let from = fromAccountId, let to = toAccountId {
                edited.fromAccountId = from
                edited.toAccountId = to
                if let source = accounts.first(where: { $0.id == from }) { edited.paymentMode = source.type == .cash ? .cash : .upi }
            }
            return edited
        }
        let wasIn = edited.transactionType == .credit
        // Untouched categories keep exactly what the entry had, including values this app doesn't recognise.
        if category != original?.category { edited.category = category }
        if subCategory != (original?.subCategory ?? .unknown) { edited.subCategory = subCategory }
        if isIn != wasIn { edited.transactionType = isIn ? .credit : .debit }
        if isIn != wasIn || selectedAccountId != originalAccountId {
            // Cash in goes TO the account, cash out comes FROM it; the other side stays empty.
            let chosen = accounts.first { $0.id == selectedAccountId }
            if let chosen { edited.paymentMode = chosen.type == .cash ? .cash : .upi }
            let accountId = selectedAccountId ?? edited.paymentMode.accountId
            edited.fromAccountId = isIn ? "" : accountId
            edited.toAccountId = isIn ? accountId : ""
        }
        return edited
    }

    public func save() async -> Bool {
        guard canSave, let edited = editedEntry() else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await money.updateCashEntry(edited, by: actorId)
            return true
        } catch {
            errorMessage = "Couldn't save the changes."
            return false
        }
    }

    public func delete() async -> Bool {
        guard let original else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await money.deleteCashEntry(original, by: actorId)
            return true
        } catch {
            errorMessage = "Couldn't delete the entry."
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
