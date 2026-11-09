//
//  HomeViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

public struct HomeKPI: Identifiable, Equatable, Sendable {
    public var id: String { title }
    public let title: String
    public let value: String
    public let caption: String?
}

/// Today's numbers for the Home dashboard, worked out from the local cache so Home opens instantly
/// and works offline. The third/fourth tiles change by shop type (designs 18, 21, 22, 23).
@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var kpis: [HomeKPI] = []
    public private(set) var recentBills: [Sale] = []
    public private(set) var lowStock: [InventoryItem] = []
    public private(set) var trending: [InventoryItem] = []
    public private(set) var hasAnySales = true
    public private(set) var hasItems = true
    public private(set) var todaySalesByStore: [String: Double] = [:]

    private let session: AppSession
    private let saleRepository: SaleRepositoryProtocol
    private let customerRepository: CustomerRepositoryProtocol
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let dailyCashflowRepository: DailyCashflowSummaryRepositoryProtocol

    public init(session: AppSession,
                saleRepository: SaleRepositoryProtocol,
                customerRepository: CustomerRepositoryProtocol,
                inventoryRepository: InventoryItemRepositoryProtocol,
                dailyCashflowRepository: DailyCashflowSummaryRepositoryProtocol) {
        self.session = session
        self.saleRepository = saleRepository
        self.customerRepository = customerRepository
        self.inventoryRepository = inventoryRepository
        self.dailyCashflowRepository = dailyCashflowRepository
    }

    public func load(now: Date = Date()) async {
        let calendar = Calendar.current
        let sales = ((try? await saleRepository.getSales()) ?? []).filter { !$0.isCancelled }
        let customers = (try? await customerRepository.getCustomers()) ?? []
        let items = (try? await inventoryRepository.getInventoryItems()) ?? []
        let todaySummary = try? await dailyCashflowRepository.getDailyCashflowSummary(id: now.toDayId)

        hasAnySales = !sales.isEmpty
        hasItems = !items.isEmpty
        let today = sales.filter { calendar.isDate($0.timestamp, inSameDayAs: now) && !$0.isReturn }
        let sameDayLastWeek = calendar.date(byAdding: .day, value: -7, to: now)!
        let lastWeek = sales.filter { calendar.isDate($0.timestamp, inSameDayAs: sameDayLastWeek) && !$0.isReturn }
        let todayTotal = today.reduce(0) { $0 + $1.netPayable } - sales.filter { $0.isReturn && calendar.isDate($0.timestamp, inSameDayAs: now) }.reduce(0) { $0 + abs($1.netPayable) }
        let lastWeekTotal = lastWeek.reduce(0) { $0 + $1.netPayable }

        recentBills = Array(sales.sorted { $0.timestamp > $1.timestamp }.prefix(3))
        lowStock = items.filter(\.isLowStock).sorted { $0.currentStock < $1.currentStock }
        todaySalesByStore = Dictionary(grouping: today, by: { $0.storeId ?? Store.defaultId })
            .mapValues { $0.reduce(0) { $0 + $1.netPayable } }

        var qtyByItem: [String: (name: String, qty: Int)] = [:]
        for item in today.flatMap(\.items) {
            qtyByItem[item.categoryId, default: (item.categoryName, 0)].qty += item.qty
        }
        let topItem = qtyByItem.max { $0.value.qty < $1.value.qty }?.value.name ?? "—"
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        var weekQty: [String: Int] = [:]
        for item in sales.filter({ $0.timestamp >= weekAgo }).flatMap(\.items) { weekQty[item.categoryId, default: 0] += item.qty }
        trending = items.filter { weekQty[$0.id] != nil }.sorted { (weekQty[$0.id] ?? 0) > (weekQty[$1.id] ?? 0) }.prefix(3).map { $0 }

        let salesKPI = HomeKPI(title: session.vertical == .parlour ? "Revenue" : "Today's sales", value: Money.format(todayTotal),
                               caption: Self.trendCaption(todayTotal, lastWeekTotal))
        let billsKPI = HomeKPI(title: "Bills", value: "\(today.count)",
                               caption: today.isEmpty ? nil : "avg \(Money.format(todayTotal / Double(today.count)))")

        switch session.vertical {
        case .kirana:
            let openingCash = todaySummary?.openingBalances.first { $0.name.lowercased() == "cash" }?.balance ?? 0
            let cashIn = today.reduce(0) { $0 + ($1.payments[.cash] ?? 0) }
            let dues = customers.filter { $0.dueBalance > 0 }
            kpis = [salesKPI, billsKPI,
                    HomeKPI(title: "Cash in hand", value: Money.format(openingCash + cashIn), caption: nil),
                    HomeKPI(title: "Dues", value: Money.format(dues.reduce(0) { $0 + $1.dueBalance }),
                            caption: dues.isEmpty ? nil : "\(dues.count) customers")]
        case .fancy:
            kpis = [salesKPI, billsKPI,
                    HomeKPI(title: "Top item", value: topItem, caption: nil),
                    HomeKPI(title: "Low stock", value: "\(lowStock.count) items", caption: nil)]
        case .jewellery:
            let pieces = today.flatMap(\.items).reduce(0) { $0 + $1.qty }
            let buyerPhones = Set(today.map(\.customerPhone).filter { !$0.isEmpty })
            let repeatCount = customers.filter { buyerPhones.contains($0.phone) && $0.totalSales > 1 }.count
            let repeatPercent = buyerPhones.isEmpty ? 0 : Int(Double(repeatCount) / Double(buyerPhones.count) * 100)
            kpis = [salesKPI,
                    HomeKPI(title: "Pieces sold", value: "\(pieces)", caption: nil),
                    HomeKPI(title: "Top design", value: topItem, caption: nil),
                    HomeKPI(title: "Repeat buyers", value: "\(repeatPercent)%", caption: nil)]
        case .parlour:
            let services = today.flatMap(\.items).reduce(0) { $0 + $1.qty }
            kpis = [salesKPI,
                    HomeKPI(title: "Services", value: "\(services)", caption: nil),
                    HomeKPI(title: "Top service", value: topItem, caption: nil),
                    HomeKPI(title: "Packages used", value: "\(today.filter { $0.source == "package" }.count)", caption: nil)]
        }
    }

    static func trendCaption(_ today: Double, _ previous: Double) -> String? {
        guard previous > 0 else { return nil }
        let change = Int(((today - previous) / previous * 100).rounded())
        return "\(change >= 0 ? "+" : "")\(change)% vs last week"
    }

    public var firstRunSteps: [FirstRunStep] {
        [
            FirstRunStep(id: "items", title: "Add your items", subtitle: "Or import them from Excel/CSV", isDone: hasItems),
            FirstRunStep(id: "balances", title: "Opening balances", subtitle: "Dues and cash from before Apoorva",
                         isDone: session.settings.profile.openingBalancesSavedAt != nil),
            FirstRunStep(id: "bill", title: "Create your first bill", subtitle: "Tap + at the bottom", isDone: hasAnySales)
        ]
    }

    public var showsFirstRunGuide: Bool { !hasAnySales && !session.isDemo }

    public var showsUsageBanner: Bool {
        guard session.planStatus.isNearLimit else { return false }
        if let snoozed = session.settings.plan.usageReminderSnoozedUntil, snoozed > Date() { return false }
        return true
    }

    public func snoozeUsageReminder() async {
        try? await session.saveSettings { $0.plan.usageReminderSnoozedUntil = Date().addingTimeInterval(86_400) }
    }
}

extension Date {
    /// `DailyCashflowSummary` doc id format.
    var toDayId: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: self)
    }
}
