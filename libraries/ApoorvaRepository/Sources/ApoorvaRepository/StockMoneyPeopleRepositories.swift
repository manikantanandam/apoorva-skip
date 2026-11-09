//
//  StockMoneyPeopleRepositories.swift
//  ApoorvaRepository
//
//  Writes that touch several collections at once: stock adjustments and purchases, cash
//  entries, expenses and day close, salary and attendance. Each keeps the cash book (the
//  legacy `cashflow` collection) and the audit log in step. None of it is atomic.
//

import Foundation
import ApoorvaModels

// MARK: - Cash book

/// Writes `CashflowTransaction`s so money in/out shows in the existing cashflow screens.
public struct CashBook: Sendable {
    private let repository: CashflowTransactionRepositoryProtocol?

    public init(repository: CashflowTransactionRepositoryProtocol?) {
        self.repository = repository
    }

    /// `mode` is "cash", or anything else (upi, card, bank), which lands in the bank account.
    public func record(_ type: CashflowTransaction.TransactionType, amount: Double, mode: String, category: CashflowCategory,
                       subCategory: CashflowSubCategory? = nil, particulars: String, person: String? = nil,
                       at date: Date = Date()) async throws {
        guard let repository, amount > 0, mode != PaymentMode.credit.rawValue else { return }
        let account: CashflowTransaction.PaymentMode = mode == "cash" ? .cash : .upi
        try await repository.saveCashflowTransaction(transaction: CashflowTransaction(
            timestamp: date, particulars: particulars, amount: amount, transactionType: type, paymentMode: account,
            category: category, subCategory: subCategory,
            fromAccountId: type == .debit ? account.accountId : "", toAccountId: type == .credit ? account.accountId : "",
            person: person, timestampInMs: date.timeIntervalSince1970, updatedAtInMs: Date().timeIntervalSince1970))
    }
}

extension ExpenseCategory {
    var cashflow: (CashflowCategory, CashflowSubCategory?) {
        switch self {
        case .rent: (.utilities, .rent)
        case .salary: (.miscellaneous, .general)
        case .electricity: (.utilities, .electricity)
        case .transport: (.miscellaneous, .transport)
        case .repairs: (.maintenanceAndRepairs, .general)
        case .supplier: (.inventory, .readyStock)
        case .tea: (.miscellaneous, .food)
        case .other: (.miscellaneous, .general)
        }
    }
}

// MARK: - Stock

public enum StockAdjustment: Sendable, Equatable {
    case add(Int), remove(Int), setExact(Int)

    func newStock(from current: Int) -> Int {
        switch self {
        case .add(let quantity): current + quantity
        case .remove(let quantity): current - quantity
        case .setExact(let quantity): quantity
        }
    }
}

public protocol StockRepositoryProtocol: Sendable {
    @discardableResult
    func adjust(itemId: String, _ adjustment: StockAdjustment, reason: StockMovementReason, note: String?, by actorId: String) async throws -> InventoryItem
    func recordPurchase(_ purchase: Purchase, by actorId: String) async throws
    func paySupplier(_ supplier: Supplier, amount: Double, mode: String, by actorId: String) async throws
}

public enum StockError: Error, Equatable {
    case itemNotFound
    case invalidAmount
}

public final actor StockRepository: StockRepositoryProtocol {
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let movements: any OrgCollectionRepositoryProtocol<StockMovement>
    private let purchases: any OrgCollectionRepositoryProtocol<Purchase>
    private let supplierLedger: any OrgCollectionRepositoryProtocol<SupplierLedgerEntry>
    private let cashBook: CashBook
    private let audit: AuditLogging?

    public init(inventoryRepository: InventoryItemRepositoryProtocol, movements: any OrgCollectionRepositoryProtocol<StockMovement>,
                purchases: any OrgCollectionRepositoryProtocol<Purchase>,
                supplierLedger: any OrgCollectionRepositoryProtocol<SupplierLedgerEntry>, cashBook: CashBook, audit: AuditLogging?) {
        self.inventoryRepository = inventoryRepository
        self.movements = movements
        self.purchases = purchases
        self.supplierLedger = supplierLedger
        self.cashBook = cashBook
        self.audit = audit
    }

    public func adjust(itemId: String, _ adjustment: StockAdjustment, reason: StockMovementReason, note: String?,
                       by actorId: String) async throws -> InventoryItem {
        guard var item = try await inventoryRepository.getInventoryItems().first(where: { $0.id == itemId }) else {
            throw StockError.itemNotFound
        }
        let before = item.currentStock
        item.currentStock = adjustment.newStock(from: before)
        item.updatedAt = Date()
        try await inventoryRepository.updateInventoryItem(item)
        let delta = Double(item.currentStock - before)
        if delta != 0 {
            try await movements.save(StockMovement(itemId: item.id, itemName: item.name, delta: delta, reason: reason,
                                                   note: note, createdBy: actorId))
        }
        await audit?.log(.stock, action: "stock.adjust",
                         summary: "\(item.name): \(before) → \(item.currentStock) (\(reason.rawValue))\(note.map { " · \($0)" } ?? "")",
                         targetId: item.id)
        return item
    }

    public func recordPurchase(_ purchase: Purchase, by actorId: String) async throws {
        guard purchase.total > 0 else { throw StockError.invalidAmount }
        try await purchases.save(purchase)
        let sign: Double = purchase.isReturn ? -1 : 1
        if !purchase.lines.isEmpty {
            let items = try await inventoryRepository.getInventoryItems()
            var moved: [StockMovement] = []
            for line in purchase.lines where line.quantity > 0 {
                moved.append(StockMovement(itemId: line.itemId, itemName: line.itemName, delta: line.quantity * sign,
                                           reason: purchase.isReturn ? .purchaseReturn : .purchase, refId: purchase.id, createdBy: actorId))
                guard var item = items.first(where: { $0.id == line.itemId }) else { continue }
                item.currentStock += Int((line.quantity * sign).rounded())
                if !purchase.isReturn && line.unitCost > 0 { item.costPrice = line.unitCost }
                item.updatedAt = Date()
                try await inventoryRepository.updateInventoryItem(item)
            }
            try await movements.saveAll(moved)
        }
        // The supplier is owed the whole bill; a payment made now is a separate entry so the ledger reads naturally.
        try await supplierLedger.save(SupplierLedgerEntry(supplierId: purchase.supplierId,
                                                          kind: purchase.isReturn ? .purchaseReturn : .purchase,
                                                          amount: purchase.total * sign, purchaseId: purchase.id,
                                                          note: "\(purchase.isReturn ? "Return" : "Purchase") #\(purchase.number)",
                                                          createdBy: actorId))
        if purchase.paid > 0 {
            try await supplierLedger.save(SupplierLedgerEntry(supplierId: purchase.supplierId, kind: .payment,
                                                              amount: -purchase.paid * sign, mode: purchase.paidMode,
                                                              purchaseId: purchase.id, note: "Paid with #\(purchase.number)",
                                                              createdBy: actorId))
            try? await cashBook.record(purchase.isReturn ? .credit : .debit, amount: purchase.paid, mode: purchase.paidMode,
                                       category: .inventory, subCategory: .readyStock,
                                       particulars: "\(purchase.isReturn ? "Refund from" : "Purchase from") \(purchase.supplierName) #\(purchase.number)",
                                       person: purchase.supplierName, at: purchase.createdAt)
        }
        await audit?.log(.stock, action: purchase.isReturn ? "purchase.return" : "purchase.create",
                         summary: "\(purchase.supplierName) #\(purchase.number) · ₹\(Int(purchase.total)) · paid ₹\(Int(purchase.paid))",
                         targetId: purchase.id)
    }

    public func paySupplier(_ supplier: Supplier, amount: Double, mode: String, by actorId: String) async throws {
        guard amount > 0 else { throw StockError.invalidAmount }
        try await supplierLedger.save(SupplierLedgerEntry(supplierId: supplier.id, kind: .payment, amount: -amount, mode: mode,
                                                          note: "Payment · \(mode.uppercased())", createdBy: actorId))
        try? await cashBook.record(.debit, amount: amount, mode: mode, category: .inventory, subCategory: .readyStock,
                                   particulars: "Supplier payment · \(supplier.name)", person: supplier.name)
        await audit?.log(.money, action: "supplier.pay", summary: "Paid \(supplier.name) ₹\(Int(amount)) by \(mode.uppercased())",
                         targetId: supplier.id)
    }
}

// MARK: - Money

public protocol MoneyRepositoryProtocol: Sendable {
    func addCashEntry(isIn: Bool, amount: Double, category: ExpenseCategory?, particulars: String, by actorId: String) async throws
    func saveExpense(_ expense: Expense) async throws
    func closeDay(_ close: DayClose) async throws
    func reopenDay(_ day: Date, by actorId: String) async throws
}

public final actor MoneyRepository: MoneyRepositoryProtocol {
    private let expenses: any OrgCollectionRepositoryProtocol<Expense>
    private let dayCloses: any OrgCollectionRepositoryProtocol<DayClose>
    private let summaries: DailyCashflowSummaryRepositoryProtocol?
    private let cashBook: CashBook
    private let audit: AuditLogging?

    public init(expenses: any OrgCollectionRepositoryProtocol<Expense>, dayCloses: any OrgCollectionRepositoryProtocol<DayClose>,
                summaries: DailyCashflowSummaryRepositoryProtocol?, cashBook: CashBook, audit: AuditLogging?) {
        self.expenses = expenses
        self.dayCloses = dayCloses
        self.summaries = summaries
        self.cashBook = cashBook
        self.audit = audit
    }

    public func addCashEntry(isIn: Bool, amount: Double, category: ExpenseCategory?, particulars: String, by actorId: String) async throws {
        let mapped = category?.cashflow ?? (isIn ? (.salesRevenue, nil) : (.miscellaneous, .general))
        try await cashBook.record(isIn ? .credit : .debit, amount: amount, mode: "cash", category: mapped.0, subCategory: mapped.1,
                                  particulars: particulars)
        await audit?.log(.money, action: isIn ? "cash.in" : "cash.out", summary: "\(particulars) · ₹\(Int(amount))", targetId: nil)
    }

    public func saveExpense(_ expense: Expense) async throws {
        let isNew = (try? await expenses.get(id: expense.id)) == nil
        try await expenses.save(expense)
        if isNew {
            let mapped = expense.category.cashflow
            try? await cashBook.record(.debit, amount: expense.amount, mode: expense.mode, category: mapped.0, subCategory: mapped.1,
                                       particulars: expense.title, at: expense.date)
        }
        await audit?.log(.money, action: isNew ? "expense.add" : "expense.edit",
                         summary: "\(expense.title) · \(expense.category.title) · ₹\(Int(expense.amount))", targetId: expense.id)
    }

    /// Saves the close and locks the legacy daily summary with the counted cash as its closing balance.
    public func closeDay(_ close: DayClose) async throws {
        try await dayCloses.save(close)
        if let summaries {
            let cash = CashflowTransaction.PaymentMode.cash.accountId
            let closing = [AccountBalance(id: cash, name: "Cash", balance: close.countedCash)]
            let existing = try? await summaries.getDailyCashflowSummary(id: close.id)
            let summary = DailyCashflowSummary(date: close.date, openingBalances: existing?.openingBalances ?? [],
                                               closingBalances: closing, updatedAt: Date().timeIntervalSince1970, locked: true)
            if existing != nil {
                try? await summaries.updateDailyCashflowSummary(summary: summary)
            } else {
                try? await summaries.saveDailyCashflowSummary(summary: summary)
            }
            if close.carryForward, let next = Calendar.current.date(byAdding: .day, value: 1, to: close.date),
               (try? await summaries.getDailyCashflowSummary(id: next.dayKey)) == nil {
                try? await summaries.saveDailyCashflowSummary(summary: DailyCashflowSummary(
                    date: next, openingBalances: closing, closingBalances: [], updatedAt: Date().timeIntervalSince1970, locked: false))
            }
        }
        await audit?.log(.money, action: "day.close",
                         summary: "Closed \(close.id) · counted ₹\(Int(close.countedCash)) · diff ₹\(Int(close.difference))",
                         targetId: close.id)
    }

    public func reopenDay(_ day: Date, by actorId: String) async throws {
        if var close = try await dayCloses.get(id: day.dayKey) {
            close.isDeleted = true
            close.updatedAt = Date()
            try await dayCloses.save(close)
        }
        if let summaries, let summary = try? await summaries.getDailyCashflowSummary(id: day.dayKey) {
            try? await summaries.updateDailyCashflowSummary(summary: summary.copyWith(updatedAt: Date().timeIntervalSince1970, locked: false))
        }
        await audit?.log(.money, action: "day.reopen", summary: "Reopened \(day.dayKey)", targetId: day.dayKey)
    }
}

// MARK: - People

public protocol PeopleRepositoryProtocol: Sendable {
    func mark(_ record: AttendanceRecord) async throws
    func pay(_ payment: SalaryPayment) async throws
}

public final actor PeopleRepository: PeopleRepositoryProtocol {
    private let attendance: any OrgCollectionRepositoryProtocol<AttendanceRecord>
    private let salaryPayments: any OrgCollectionRepositoryProtocol<SalaryPayment>
    private let expenses: any OrgCollectionRepositoryProtocol<Expense>
    private let cashBook: CashBook
    private let audit: AuditLogging?

    public init(attendance: any OrgCollectionRepositoryProtocol<AttendanceRecord>,
                salaryPayments: any OrgCollectionRepositoryProtocol<SalaryPayment>,
                expenses: any OrgCollectionRepositoryProtocol<Expense>, cashBook: CashBook, audit: AuditLogging?) {
        self.attendance = attendance
        self.salaryPayments = salaryPayments
        self.expenses = expenses
        self.cashBook = cashBook
        self.audit = audit
    }

    public func mark(_ record: AttendanceRecord) async throws {
        try await attendance.save(record)
    }

    /// A salary payment also becomes a Salary expense; both kinds go through the cash book.
    public func pay(_ payment: SalaryPayment) async throws {
        try await salaryPayments.save(payment)
        let label = payment.kind == .salary ? "\(payment.memberName) salary" : "\(payment.memberName) advance"
        if payment.kind == .salary {
            try await expenses.save(Expense(title: label, category: .salary, amount: payment.amount, mode: payment.mode,
                                            date: payment.createdAt, createdBy: payment.createdBy))
        }
        try? await cashBook.record(.debit, amount: payment.amount, mode: payment.mode, category: .miscellaneous, subCategory: .general,
                                   particulars: label, person: payment.memberName, at: payment.createdAt)
        await audit?.log(.staff, action: payment.kind == .salary ? "salary.pay" : "salary.advance",
                         summary: "\(label) · ₹\(Int(payment.amount)) · \(payment.month)", targetId: payment.memberId)
    }
}
