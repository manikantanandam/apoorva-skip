//
//  SupplierViewModels.swift
//  ApoorvaModules
//
//  Reorder (79), suppliers (80), supplier detail (81), new supplier, purchase (82).
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

// MARK: - Suppliers (80)

@MainActor
@Observable
public final class SuppliersViewModel {
    public private(set) var suppliers: [Supplier] = []
    public private(set) var ledger: [SupplierLedgerEntry] = []
    public private(set) var lastPurchase: [String: Date] = [:]
    public var searchText = ""

    private let repository: any OrgCollectionRepositoryProtocol<Supplier>
    private let ledgerRepository: any OrgCollectionRepositoryProtocol<SupplierLedgerEntry>

    public init(repository: any OrgCollectionRepositoryProtocol<Supplier>,
                ledgerRepository: any OrgCollectionRepositoryProtocol<SupplierLedgerEntry>) {
        self.repository = repository
        self.ledgerRepository = ledgerRepository
    }

    public func load() async {
        suppliers = ((try? await repository.all()) ?? []).filter { !$0.isDeleted }
        ledger = ((try? await ledgerRepository.all()) ?? []).filter { !$0.isDeleted }
        lastPurchase = Dictionary(grouping: ledger.filter { $0.kind == .purchase }, by: \.supplierId)
            .compactMapValues { $0.map(\.createdAt).max() }
        suppliers.sort { owed($0) == owed($1) ? $0.name < $1.name : owed($0) > owed($1) }
    }

    public func owed(_ supplier: Supplier) -> Double { ledger.owed(to: supplier) }
    public var totalOwed: Double { suppliers.reduce(0) { $0 + max(0, owed($1)) } }

    public var visible: [Supplier] {
        guard !searchText.isEmpty else { return suppliers }
        return suppliers.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.phone.contains(searchText) }
    }

    public func subtitle(_ supplier: Supplier) -> String {
        let what = supplier.notes.isEmpty ? supplier.phone : supplier.notes
        guard let last = lastPurchase[supplier.id] else { return what }
        return "\(what) · last purchase \(Calendar.current.isDateInToday(last) ? "today" : last.shortDay)"
    }
}

// MARK: - New supplier

@MainActor
@Observable
public final class SupplierFormViewModel {
    public var name = ""
    public var phone = ""
    public var what = ""
    public var openingDueText = ""
    public var errorMessage: String?

    private let repository: any OrgCollectionRepositoryProtocol<Supplier>

    public init(repository: any OrgCollectionRepositoryProtocol<Supplier>) {
        self.repository = repository
    }

    public var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    public func save() async -> Supplier? {
        guard canSave else { return nil }
        let supplier = Supplier(name: name.trimmingCharacters(in: .whitespaces), phone: PhoneNumber.normalize(phone),
                                openingDue: Double(openingDueText) ?? 0, notes: what)
        do {
            try await repository.save(supplier)
            return supplier
        } catch {
            errorMessage = "Couldn't save the supplier."
            return nil
        }
    }
}

// MARK: - Supplier detail (81)

@MainActor
@Observable
public final class SupplierDetailViewModel {
    public let supplierId: String
    public private(set) var supplier: Supplier?
    public private(set) var entries: [SupplierLedgerEntry] = []
    public var payAmountText = ""
    public var payMode: PaymentMode = .upi
    public var errorMessage: String?

    private let repository: any OrgCollectionRepositoryProtocol<Supplier>
    private let ledgerRepository: any OrgCollectionRepositoryProtocol<SupplierLedgerEntry>
    private let stock: StockRepositoryProtocol
    private let actorId: String

    public init(supplierId: String, repository: any OrgCollectionRepositoryProtocol<Supplier>,
                ledgerRepository: any OrgCollectionRepositoryProtocol<SupplierLedgerEntry>, stock: StockRepositoryProtocol, actorId: String) {
        self.supplierId = supplierId
        self.repository = repository
        self.ledgerRepository = ledgerRepository
        self.stock = stock
        self.actorId = actorId
    }

    public func load() async {
        supplier = try? await repository.get(id: supplierId)
        entries = ((try? await ledgerRepository.all()) ?? []).filter { $0.supplierId == supplierId && !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public var owed: Double { supplier.map { entries.owed(to: $0) } ?? 0 }

    public var boughtThisMonth: Double {
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        return entries.filter { $0.kind == .purchase && $0.createdAt >= start }.reduce(0) { $0 + $1.amount }
    }

    /// When the shop last owed nothing (approximate).
    public var owedSince: Date? {
        guard owed > 0 else { return nil }
        var running = supplier?.openingDue ?? 0
        var since: Date? = running > 0 ? supplier?.createdAt : nil
        for entry in entries.reversed() {
            if running <= 0 && entry.amount > 0 { since = entry.createdAt }
            running += entry.amount
        }
        return since
    }

    public func pay() async -> Bool {
        guard let supplier, let amount = Double(payAmountText), amount > 0 else { return false }
        do {
            try await stock.paySupplier(supplier, amount: amount, mode: payMode.rawValue, by: actorId)
            payAmountText = ""
            await load()
            return true
        } catch {
            errorMessage = "Couldn't record the payment."
            return false
        }
    }

    public var whatsAppURL: URL? {
        supplier.flatMap { MessageLink.whatsApp(to: $0.phone, text: "Namaste \($0.name), ") }
    }
}

// MARK: - Purchase (82)

@MainActor
@Observable
public final class PurchaseFormViewModel {
    public enum Kind: String, CaseIterable, Sendable { case purchase = "Purchase", supplierReturn = "Return to supplier" }
    public enum Entry: String, CaseIterable, Sendable { case items = "With items", totalOnly = "Total only" }
    public enum Payment: String, CaseIterable, Sendable { case paidNow = "Paid now", credit = "On credit", partPaid = "Part paid" }

    public private(set) var suppliers: [Supplier] = []
    public private(set) var items: [InventoryItem] = []
    public var supplierId: String?
    public var kind: Kind = .purchase
    public var entry: Entry = .items
    public var lines: [PurchaseLine] = []
    public var totalText = ""
    public var payment: Payment = .credit
    public var paidText = ""
    public var paidMode: PaymentMode = .cash
    public var note = ""
    public var itemSearch = ""
    public var isSaving = false
    public var errorMessage: String?

    private let supplierRepository: any OrgCollectionRepositoryProtocol<Supplier>
    private let purchaseRepository: any OrgCollectionRepositoryProtocol<Purchase>
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let stock: StockRepositoryProtocol
    private let actorId: String

    public init(supplierId: String?, prefill: [PurchaseLine] = [], supplierRepository: any OrgCollectionRepositoryProtocol<Supplier>,
                purchaseRepository: any OrgCollectionRepositoryProtocol<Purchase>, inventoryRepository: InventoryItemRepositoryProtocol,
                stock: StockRepositoryProtocol, actorId: String) {
        self.supplierId = supplierId
        self.lines = prefill
        self.supplierRepository = supplierRepository
        self.purchaseRepository = purchaseRepository
        self.inventoryRepository = inventoryRepository
        self.stock = stock
        self.actorId = actorId
    }

    public func load() async {
        suppliers = ((try? await supplierRepository.all()) ?? []).filter { !$0.isDeleted }.sorted { $0.name < $1.name }
        items = ((try? await inventoryRepository.getInventoryItems()) ?? []).filter { !$0.isDeleted }.sorted()
        if supplierId == nil { supplierId = suppliers.first?.id }
    }

    public var supplier: Supplier? { suppliers.first { $0.id == supplierId } }

    public var itemMatches: [InventoryItem] {
        let query = itemSearch.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return [] }
        return Array(items.filter { $0.name.localizedCaseInsensitiveContains(query) && !lines.map(\.itemId).contains($0.id) }.prefix(5))
    }

    public func add(_ item: InventoryItem) {
        lines.append(PurchaseLine(itemId: item.id, itemName: item.name, quantity: 1, unitCost: item.costPrice ?? (item.sellPrice ?? 0) * 0.8))
        itemSearch = ""
    }

    public func update(_ itemId: String, quantity: Double? = nil, unitCost: Double? = nil) {
        guard let index = lines.firstIndex(where: { $0.itemId == itemId }) else { return }
        if let quantity { lines[index].quantity = max(0, quantity) }
        if let unitCost { lines[index].unitCost = max(0, unitCost) }
    }

    public func remove(_ itemId: String) { lines.removeAll { $0.itemId == itemId } }

    public var total: Double {
        entry == .items ? lines.reduce(0) { $0 + $1.total } : (Double(totalText) ?? 0)
    }

    public var paid: Double {
        switch payment {
        case .paidNow: total
        case .credit: 0
        case .partPaid: min(Double(paidText) ?? 0, total)
        }
    }

    public var saveTitle: String {
        switch payment {
        case .paidNow: "Save · \(Money.format(total)) paid"
        case .credit: "Save · \(Money.format(total)) on credit"
        case .partPaid: "Save · \(Money.format(total - paid)) on credit"
        }
    }

    public var canSave: Bool { supplier != nil && total > 0 }

    public func save() async -> Purchase? {
        guard canSave, let supplier else { return nil }
        isSaving = true
        defer { isSaving = false }
        let count = ((try? await purchaseRepository.all()) ?? []).count
        let purchase = Purchase(number: "P-\(String(format: "%03d", count + 1))", supplierId: supplier.id, supplierName: supplier.name,
                                isReturn: kind == .supplierReturn, lines: entry == .items ? lines : [], total: total, paid: paid,
                                paidMode: paidMode.rawValue, note: note, createdBy: actorId)
        do {
            try await stock.recordPurchase(purchase, by: actorId)
            return purchase
        } catch {
            errorMessage = "Couldn't save the purchase. Try again."
            return nil
        }
    }
}

// MARK: - Reorder (79)

@MainActor
@Observable
public final class ReorderViewModel {
    public struct Line: Identifiable, Sendable {
        public var id: String { item.id }
        public let item: InventoryItem
        public var quantity: Int
        public var isSelected: Bool
    }

    public private(set) var lines: [Line] = []
    public private(set) var suppliers: [Supplier] = []
    public var supplierId: String?

    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let supplierRepository: any OrgCollectionRepositoryProtocol<Supplier>
    private let shopName: String

    public init(inventoryRepository: InventoryItemRepositoryProtocol, supplierRepository: any OrgCollectionRepositoryProtocol<Supplier>,
                shopName: String) {
        self.inventoryRepository = inventoryRepository
        self.supplierRepository = supplierRepository
        self.shopName = shopName
    }

    /// Low-stock items, suggesting enough to reach twice the low mark (at least 10).
    public func load() async {
        let items = ((try? await inventoryRepository.getInventoryItems()) ?? []).filter { !$0.isDeleted && $0.isLowStock }
        lines = items.sorted { $0.currentStock < $1.currentStock }.map { item in
            let target = max(10, (item.lowStockThreshold ?? 5) * 2)
            return Line(item: item, quantity: max(1, target - item.currentStock), isSelected: true)
        }
        suppliers = ((try? await supplierRepository.all()) ?? []).filter { !$0.isDeleted }.sorted { $0.name < $1.name }
        if supplierId == nil { supplierId = suppliers.first?.id }
    }

    public var supplier: Supplier? { suppliers.first { $0.id == supplierId } }
    public var selected: [Line] { lines.filter(\.isSelected) }

    public func toggle(_ id: String) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].isSelected.toggle()
    }

    public func setQuantity(_ quantity: Int, for id: String) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].quantity = max(1, quantity)
    }

    public var message: String {
        var text = "Namaste\(supplier.map { " \($0.name)" } ?? ""), please send:\n"
        text += selected.map { "• \($0.item.name) × \($0.quantity)" }.joined(separator: "\n")
        return text + "\n– \(shopName)"
    }

    public var whatsAppURL: URL? { MessageLink.whatsApp(to: supplier?.phone, text: message) }

    /// Purchase lines for when the stock arrives.
    public var purchaseLines: [PurchaseLine] {
        selected.map { PurchaseLine(itemId: $0.item.id, itemName: $0.item.name, quantity: Double($0.quantity),
                                    unitCost: $0.item.costPrice ?? ($0.item.sellPrice ?? 0) * 0.8) }
    }
}
