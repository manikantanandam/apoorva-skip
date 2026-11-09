//
//  SaleLifecycleRepository.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaModels

public enum SaleLifecycleError: Error, LocalizedError, Equatable {
    case notFound
    case alreadyCancelled
    case undoWindowPassed

    public var errorDescription: String? {
        switch self {
        case .notFound: "This bill couldn't be found."
        case .alreadyCancelled: "This bill is already cancelled."
        case .undoWindowPassed: "The 5-minute undo window has passed. Cancel the bill instead."
        }
    }
}

public protocol SaleLifecycleRepositoryProtocol: Sendable {
    /// Stock out, credit due onto the customer's ledger. Call once after a sale is confirmed.
    func recordEffects(of sale: Sale, by actorId: String) async throws
    /// Cancels with a reason and reverses stock and dues. Never deletes the bill.
    @discardableResult
    func cancel(saleId: String, reason: String, by actorId: String) async throws -> Sale
    /// Undo within 5 minutes of saving (cancel with reason "Undo").
    @discardableResult
    func undo(saleId: String, by actorId: String, now: Date) async throws -> Sale
    /// Saves edited lines/totals, adjusting stock and dues by the difference.
    func edit(_ edited: Sale, reason: String, by actorId: String) async throws
}

/// Keeps a bill's side effects (stock, customer dues, audit trail) consistent across
/// save → cancel/undo/edit. Each step is idempotent enough to retry; it's not atomic.
public final actor SaleLifecycleRepository: SaleLifecycleRepositoryProtocol {
    public static let undoWindow: TimeInterval = 5 * 60

    private let saleRepository: SaleRepositoryProtocol
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let customerRepository: CustomerRepositoryProtocol
    private let stockMovements: any OrgCollectionRepositoryProtocol<StockMovement>
    private let ledger: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>
    private let audit: AuditLogging

    public init(saleRepository: SaleRepositoryProtocol,
                inventoryRepository: InventoryItemRepositoryProtocol,
                customerRepository: CustomerRepositoryProtocol,
                stockMovements: any OrgCollectionRepositoryProtocol<StockMovement>,
                ledger: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>,
                audit: AuditLogging) {
        self.saleRepository = saleRepository
        self.inventoryRepository = inventoryRepository
        self.customerRepository = customerRepository
        self.stockMovements = stockMovements
        self.ledger = ledger
        self.audit = audit
    }

    public func recordEffects(of sale: Sale, by actorId: String) async throws {
        let direction: Double = sale.isReturn ? 1 : -1
        let reason: StockMovementReason = sale.isReturn ? .customerReturn : .sale
        try await moveStock(for: sale.items.map { ($0.categoryId, $0.categoryName, Double($0.qty) * direction) },
                            reason: reason, refId: sale.id, actorId: actorId)
        let credit = sale.payments[.credit] ?? 0
        if credit > 0 {
            try await addDue(phone: sale.customerPhone, name: sale.customerName, amount: credit,
                             kind: .sale, saleId: sale.id, note: "Bill \(sale.billNumber ?? sale.id.prefix(6).description)", actorId: actorId)
        }
    }

    public func cancel(saleId: String, reason: String, by actorId: String) async throws -> Sale {
        guard let original = try await saleRepository.getSale(id: saleId) else { throw SaleLifecycleError.notFound }
        guard !original.isCancelled else { throw SaleLifecycleError.alreadyCancelled }
        guard let cancelled = try await saleRepository.cancelSale(id: saleId, reason: reason, by: actorId) else {
            throw SaleLifecycleError.alreadyCancelled
        }
        // Put the stock back (or take it back out, for a return).
        let direction: Double = original.isReturn ? -1 : 1
        try await moveStock(for: original.items.map { ($0.categoryId, $0.categoryName, Double($0.qty) * direction) },
                            reason: .cancel, refId: saleId, actorId: actorId)
        let credit = original.payments[.credit] ?? 0
        if credit > 0 {
            try await addDue(phone: original.customerPhone, name: original.customerName, amount: -credit,
                             kind: .reversal, saleId: saleId, note: "Cancelled: \(reason)", actorId: actorId)
        }
        await audit.log(.bills, action: reason == "Undo" ? "bill.undo" : "bill.cancel",
                        summary: "\(reason == "Undo" ? "Undid" : "Cancelled") bill \(original.billNumber ?? saleId.prefix(6).description) · \(Self.money(original.netPayable)) · \(reason)",
                        targetId: saleId)
        return cancelled
    }

    public func undo(saleId: String, by actorId: String, now: Date = Date()) async throws -> Sale {
        guard let sale = try await saleRepository.getSale(id: saleId) else { throw SaleLifecycleError.notFound }
        guard now.timeIntervalSince(sale.timestamp) <= Self.undoWindow else { throw SaleLifecycleError.undoWindowPassed }
        return try await cancel(saleId: saleId, reason: "Undo", by: actorId)
    }

    public func edit(_ edited: Sale, reason: String, by actorId: String) async throws {
        guard let original = try await saleRepository.getSale(id: edited.id) else { throw SaleLifecycleError.notFound }
        guard !original.isCancelled else { throw SaleLifecycleError.alreadyCancelled }

        // Stock: apply the per-item quantity difference.
        var before: [String: (String, Int)] = [:]
        for item in original.items { before[item.categoryId, default: (item.categoryName, 0)].1 += item.qty }
        var after: [String: (String, Int)] = [:]
        for item in edited.items { after[item.categoryId, default: (item.categoryName, 0)].1 += item.qty }
        let ids = Set(before.keys).union(after.keys)
        let deltas = ids.compactMap { id -> (String, String, Double)? in
            let soldBefore = before[id]?.1 ?? 0
            let soldAfter = after[id]?.1 ?? 0
            guard soldBefore != soldAfter else { return nil }
            // Selling fewer puts stock back.
            return (id, after[id]?.0 ?? before[id]?.0 ?? "", Double(soldBefore - soldAfter))
        }
        try await moveStock(for: deltas, reason: .adjustment, refId: edited.id, actorId: actorId)

        let creditDelta = (edited.payments[.credit] ?? 0) - (original.payments[.credit] ?? 0)
        if creditDelta != 0 {
            try await addDue(phone: edited.customerPhone, name: edited.customerName, amount: creditDelta,
                             kind: .adjustment, saleId: edited.id, note: "Bill edited: \(reason)", actorId: actorId)
        }
        try await saleRepository.editSale(edited, reason: reason)
        await audit.log(.bills, action: "bill.edit",
                        summary: "Edited bill \(edited.billNumber ?? edited.id.prefix(6).description): \(Self.money(original.netPayable)) → \(Self.money(edited.netPayable)) · \(reason)",
                        targetId: edited.id)
    }

    // MARK: - Helpers

    private func moveStock(for lines: [(id: String, name: String, delta: Double)], reason: StockMovementReason,
                           refId: String, actorId: String) async throws {
        guard !lines.isEmpty else { return }
        let items = try await inventoryRepository.getInventoryItems()
        var movements: [StockMovement] = []
        for line in lines where line.delta != 0 {
            movements.append(StockMovement(itemId: line.id, itemName: line.name, delta: line.delta, reason: reason,
                                           refId: refId, createdBy: actorId))
            guard var item = items.first(where: { $0.id == line.id }) else { continue }
            item.currentStock += Int(line.delta.rounded())
            if reason == .sale { item.lastSoldDate = Date() }
            item.updatedAt = Date()
            try await inventoryRepository.updateInventoryItem(item)
        }
        try await stockMovements.saveAll(movements)
    }

    private func addDue(phone: String, name: String, amount: Double, kind: LedgerEntryKind, saleId: String,
                        note: String, actorId: String) async throws {
        guard !phone.isEmpty else { return }
        try await ledger.save(CustomerLedgerEntry(customerPhone: phone, customerName: name, kind: kind, amount: amount,
                                                  saleId: saleId, note: note, createdBy: actorId))
        if var customer = try await customerRepository.getCustomer(phone: phone) {
            customer.dueBalance += amount
            customer.updatedAt = Date().timeIntervalSince1970
            try await customerRepository.updateCustomer(customer)
        }
    }

    private static func money(_ amount: Double) -> String {
        "₹" + String(Int(amount.rounded()))
    }
}
