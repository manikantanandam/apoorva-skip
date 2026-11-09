//
//  BillsViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

public enum BillQuickFilter: String, CaseIterable, Sendable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This week"
    case unpaid = "Unpaid"
    case cancelled = "Cancelled"
}

public enum BillDateRange: String, CaseIterable, Sendable {
    case today = "Today"
    case yesterday = "Yesterday"
    case last7Days = "Last 7 days"
    case thisMonth = "This month"
    case all = "All time"
}

public enum BillStatusFilter: String, CaseIterable, Sendable {
    case all = "All"
    case paid = "Paid"
    case due = "Due"
    case cancelled = "Cancelled"
}

/// Everything the filters sheet (design 57) can set.
public struct BillFilters: Equatable, Sendable {
    public var range: BillDateRange = .today
    public var modes: Set<PaymentMode> = []
    public var status: BillStatusFilter = .all
    public var staffIds: Set<String> = []

    public init() {}

    public var isDefault: Bool { self == BillFilters() }
}

public extension Sale {
    /// Credit portion still owed on this bill.
    var dueAmount: Double { isCancelled ? 0 : (payments[.credit] ?? 0) }
    var isDue: Bool { dueAmount > 0 }
    var primaryMode: String {
        let modes = payments.filter { $0.value > 0 }.keys.map(\.rawValue).sorted()
        if modes.count > 1 { return "Split" }
        return (modes.first ?? "cash").uppercased() == "UPI" ? "UPI" : (modes.first ?? "cash").capitalized
    }
    var displayNumber: String { "#" + (billNumber ?? String(id.prefix(6)).uppercased()) }
}

@MainActor
@Observable
public final class BillsViewModel {
    public var quick: BillQuickFilter? = .today {
        didSet { if quick != nil { filters = Self.filters(for: quick) } }
    }
    public var filters = BillFilters()
    public var searchText = ""
    public private(set) var allSales: [Sale] = []
    public private(set) var staffNames: [String: String] = [:]

    private let repository: SaleRepositoryProtocol
    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>

    public init(repository: SaleRepositoryProtocol, memberRepository: any OrgCollectionRepositoryProtocol<Member>) {
        self.repository = repository
        self.memberRepository = memberRepository
        filters = Self.filters(for: .today)
    }

    public func load() async {
        allSales = (try? await repository.getSales()) ?? []
        let members = (try? await memberRepository.all()) ?? []
        staffNames = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })
    }

    public func refresh() async {
        try? await repository.sync(force: false)
        await load()
    }

    public var sales: [Sale] {
        apply(filters, search: searchText).sorted { $0.timestamp > $1.timestamp }
    }

    /// For the filters sheet's "Show N bills" button.
    public func count(with filters: BillFilters) -> Int {
        apply(filters, search: searchText).count
    }

    public var todayTotal: Double {
        allSales.filter { !$0.isCancelled && Calendar.current.isDateInToday($0.timestamp) }.reduce(0) { $0 + $1.netPayable }
    }

    public var todayCount: Int {
        allSales.filter { !$0.isCancelled && Calendar.current.isDateInToday($0.timestamp) }.count
    }

    public var staffOptions: [(id: String, name: String)] {
        Set(allSales.map(\.staffId)).map { ($0, staffNames[$0] ?? "Staff") }.sorted { $0.name < $1.name }
    }

    public func applyFilters(_ newFilters: BillFilters) {
        filters = newFilters
        quick = nil
    }

    private func apply(_ filters: BillFilters, search: String) -> [Sale] {
        let calendar = Calendar.current
        let now = Date()
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return allSales.filter { sale in
            let inRange: Bool = switch filters.range {
            case .today: calendar.isDateInToday(sale.timestamp)
            case .yesterday: calendar.isDateInYesterday(sale.timestamp)
            case .last7Days: sale.timestamp >= calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))!
            case .thisMonth: calendar.isDate(sale.timestamp, equalTo: now, toGranularity: .month)
            case .all: true
            }
            guard inRange else { return false }
            if !filters.modes.isEmpty && !filters.modes.contains(where: { (sale.payments[$0] ?? 0) > 0 }) { return false }
            switch filters.status {
            case .all: break
            case .paid: if sale.isCancelled || sale.isDue { return false }
            case .due: if !sale.isDue { return false }
            case .cancelled: if !sale.isCancelled { return false }
            }
            if !filters.staffIds.isEmpty && !filters.staffIds.contains(sale.staffId) { return false }
            if !query.isEmpty {
                let haystack = "\(sale.customerName) \(sale.customerPhone) \(sale.displayNumber)".lowercased()
                if !haystack.contains(query) { return false }
            }
            return true
        }
    }

    static func filters(for quick: BillQuickFilter?) -> BillFilters {
        var filters = BillFilters()
        switch quick {
        case .today, nil: filters.range = .today
        case .yesterday: filters.range = .yesterday
        case .thisWeek: filters.range = .last7Days
        case .unpaid: filters.range = .all; filters.status = .due
        case .cancelled: filters.range = .all; filters.status = .cancelled
        }
        return filters
    }
}

/// Bill detail (design 55): one bill and what can be done with it.
@MainActor
@Observable
public final class BillDetailViewModel {
    public let saleId: String
    public private(set) var sale: Sale?
    public private(set) var staffName: String?
    public var errorMessage: String?

    private let repository: SaleRepositoryProtocol
    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>

    public init(saleId: String, repository: SaleRepositoryProtocol, memberRepository: any OrgCollectionRepositoryProtocol<Member>) {
        self.saleId = saleId
        self.repository = repository
        self.memberRepository = memberRepository
    }

    public func load() async {
        sale = try? await repository.getSale(id: saleId)
        if let staffId = sale?.staffId {
            staffName = (try? await memberRepository.get(id: staffId))?.name
        }
    }

    public var paid: Double {
        guard let sale else { return 0 }
        return sale.payments.filter { $0.key != .credit }.reduce(0) { $0 + $1.value }
    }

    public var shareText: String {
        guard let sale else { return "" }
        var lines = ["Bill \(sale.displayNumber) · \(sale.timestamp.formatted(date: .abbreviated, time: .shortened))"]
        for item in sale.items {
            lines.append("\(item.categoryName) × \(item.qty)  \(Money.format(item.totalAmount))")
        }
        lines.append("Total: \(Money.format(sale.netPayable))")
        if sale.isDue { lines.append("Balance due: \(Money.format(sale.dueAmount))") }
        lines.append("Thank you!")
        return lines.joined(separator: "\n")
    }
}

/// Cancel bill (design 56).
@MainActor
@Observable
public final class CancelBillViewModel {
    public static let reasons = ["Wrong items or amount", "Customer changed mind", "Duplicate bill", "Test / training bill"]

    public let saleId: String
    public var reason = CancelBillViewModel.reasons[0]
    public var note = ""
    public var isWorking = false
    public var errorMessage: String?

    private let lifecycle: SaleLifecycleRepositoryProtocol
    private let actorId: String

    public init(saleId: String, lifecycle: SaleLifecycleRepositoryProtocol, actorId: String) {
        self.saleId = saleId
        self.lifecycle = lifecycle
        self.actorId = actorId
    }

    public func cancel() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        let fullReason = note.trimmingCharacters(in: .whitespaces).isEmpty ? reason : "\(reason) — \(note)"
        do {
            try await lifecycle.cancel(saleId: saleId, reason: fullReason, by: actorId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// Edit a saved bill (design 50): change quantities or remove lines, with a reason.
@MainActor
@Observable
public final class BillEditViewModel {
    public struct Line: Identifiable {
        public let id: String
        public let item: SaleItem
        public var qty: Int
        public var isRemoved: Bool { qty == 0 }
    }

    public let saleId: String
    public private(set) var original: Sale?
    public var lines: [Line] = []
    public var reason = ""
    public var isWorking = false
    public var errorMessage: String?

    private let repository: SaleRepositoryProtocol
    private let lifecycle: SaleLifecycleRepositoryProtocol
    private let actorId: String

    public init(saleId: String, repository: SaleRepositoryProtocol, lifecycle: SaleLifecycleRepositoryProtocol, actorId: String) {
        self.saleId = saleId
        self.repository = repository
        self.lifecycle = lifecycle
        self.actorId = actorId
    }

    public func load() async {
        original = try? await repository.getSale(id: saleId)
        lines = (original?.items ?? []).map { Line(id: $0.id, item: $0, qty: $0.qty) }
    }

    public func setQty(_ qty: Int, for lineId: String) {
        guard let index = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[index].qty = max(0, qty)
    }

    public var newSubtotal: Double { lines.reduce(0) { $0 + Double($1.qty) * $1.item.finalPrice } }

    public var newTotal: Double {
        guard let original else { return 0 }
        let discount = newSubtotal * original.overallDiscountPercent / 100
        return max(0, newSubtotal - discount - original.roundOff)
    }

    public var hasChanges: Bool { lines.contains { $0.qty != $0.item.qty } }
    public var canSave: Bool { hasChanges && !reason.trimmingCharacters(in: .whitespaces).isEmpty && lines.contains { $0.qty > 0 } }

    /// The edited bill. Payments shrink or grow with the total; any change lands on the main payment mode.
    func editedSale() -> Sale? {
        guard var sale = original else { return nil }
        let items = lines.filter { $0.qty > 0 }.map {
            SaleItem(id: $0.item.id, categoryId: $0.item.categoryId, categoryName: $0.item.categoryName, qty: $0.qty,
                     stickerPrice: $0.item.stickerPrice, finalPrice: $0.item.finalPrice, discountType: $0.item.discountType)
        }
        let difference = newTotal - sale.netPayable
        var payments = sale.payments
        let mainMode = payments.max { $0.value < $1.value }?.key ?? .cash
        payments[mainMode] = max(0, (payments[mainMode] ?? 0) + difference)
        sale = Sale(id: sale.id, staffId: sale.staffId, customerPhone: sale.customerPhone, customerName: sale.customerName,
                    items: items, subtotal: newSubtotal, overallDiscountPercent: sale.overallDiscountPercent,
                    overallDiscountAmount: newSubtotal * sale.overallDiscountPercent / 100, roundOff: sale.roundOff,
                    netPayable: newTotal, payments: payments, timestamp: sale.timestamp, source: sale.source,
                    status: sale.status, whatsappStatus: sale.whatsappStatus, updatedAt: sale.updatedAt, isDeleted: false,
                    storeId: sale.storeId, billNumber: sale.billNumber, returnOfSaleId: sale.returnOfSaleId)
        return sale
    }

    public func save() async -> Bool {
        guard canSave, let edited = editedSale() else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await lifecycle.edit(edited, reason: reason.trimmingCharacters(in: .whitespaces), by: actorId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
