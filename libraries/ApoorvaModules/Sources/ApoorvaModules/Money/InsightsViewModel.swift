//
//  InsightsViewModel.swift
//  ApoorvaModules
//
//  Shop metrics from the local cache: overview (90), items (91), customers (92), staff (93),
//  staff services & commission (70), reports (94), profit (95).
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

/// Sales, cost and profit over a set of bills. Items without a cost use 80% of the selling price.
public struct ShopMetrics: Sendable {
    public struct ItemTotal: Sendable, Equatable {
        public let id: String
        public let name: String
        public let quantity: Double
        public let amount: Double
    }

    public static let estimatedCostRatio = 0.8

    public let revenue: Double
    public let billCount: Int
    public let cost: Double
    public let expenseTotal: Double
    public let byMode: [PaymentMode: Double]
    public let topItems: [ItemTotal]
    public let usesEstimatedCost: Bool

    public init(sales: [Sale], items: [InventoryItem], expenses: [Expense]) {
        let live = sales.filter { !$0.isCancelled }
        revenue = live.reduce(0) { $0 + $1.signedTotal }
        billCount = live.filter { !$0.isReturn }.count
        expenseTotal = expenses.filter { !$0.isDeleted }.reduce(0) { $0 + $1.amount }
        let costs = Dictionary(items.map { ($0.id, $0.costPrice) }, uniquingKeysWith: { first, _ in first })
        var cost = 0.0
        var estimated = false
        var totals: [String: (name: String, quantity: Double, amount: Double)] = [:]
        var modes: [PaymentMode: Double] = [:]
        for sale in live {
            let sign: Double = sale.isReturn ? -1 : 1
            for mode in PaymentMode.allCases { modes[mode, default: 0] += sale.paid(mode) }
            for line in sale.items {
                let quantity = Double(line.qty) * sign
                if let unitCost = costs[line.categoryId] ?? nil, line.weight == nil {
                    cost += unitCost * quantity
                } else {
                    cost += line.finalPrice * Self.estimatedCostRatio * quantity
                    if !line.categoryId.hasPrefix("custom-") && !line.categoryId.hasPrefix("package:") { estimated = true }
                }
                let measure = (line.weight ?? Double(line.qty)) * sign
                let current = totals[line.categoryId] ?? (line.categoryName, 0, 0)
                totals[line.categoryId] = (current.name, current.quantity + measure, current.amount + line.totalAmount * sign)
            }
        }
        self.cost = cost
        usesEstimatedCost = estimated
        byMode = modes
        topItems = totals.filter { !$0.key.hasPrefix("custom-") }
            .map { ItemTotal(id: $0.key, name: $0.value.name, quantity: $0.value.quantity, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }
    }

    public var averageBill: Double { billCount > 0 ? revenue / Double(billCount) : 0 }
    public var grossProfit: Double { revenue - cost }
    public var margin: Double { revenue > 0 ? grossProfit / revenue : 0 }
    public var netProfit: Double { grossProfit - expenseTotal }
}

public enum InsightsPeriod: String, CaseIterable, Sendable {
    case today = "Today", week = "Week", month = "Month", lastMonth = "Last month"

    /// The period and the one before it, for "+12% vs last week".
    func ranges(now: Date = Date()) -> (current: DateInterval, previous: DateInterval) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        switch self {
        case .today:
            return (DateInterval(start: today, end: end), DateInterval(start: calendar.date(byAdding: .day, value: -1, to: today)!, end: today))
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: today)!
            return (DateInterval(start: start, end: end), DateInterval(start: calendar.date(byAdding: .day, value: -7, to: start)!, end: start))
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)!.start
            let previous = calendar.date(byAdding: .month, value: -1, to: start)!
            return (DateInterval(start: start, end: end), DateInterval(start: previous, end: start))
        case .lastMonth:
            let thisMonth = calendar.dateInterval(of: .month, for: now)!.start
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonth)!
            let previous = calendar.date(byAdding: .month, value: -1, to: start)!
            return (DateInterval(start: start, end: thisMonth), DateInterval(start: previous, end: start))
        }
    }
}

@MainActor
@Observable
public final class InsightsViewModel {
    public var period: InsightsPeriod = .week

    public private(set) var sales: [Sale] = []
    public private(set) var items: [InventoryItem] = []
    public private(set) var customers: [Customer] = []
    public private(set) var members: [Member] = []
    public private(set) var expenses: [Expense] = []
    public private(set) var ledger: [CustomerLedgerEntry] = []
    public private(set) var transactions: [CashflowTransaction] = []
    public private(set) var categories: [ItemCategory] = []

    private let saleRepository: SaleRepositoryProtocol
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let customerRepository: CustomerRepositoryProtocol
    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>
    private let expenseRepository: any OrgCollectionRepositoryProtocol<Expense>
    private let ledgerRepository: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>
    private let cashflowRepository: CashflowTransactionRepositoryProtocol?
    private let categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)?
    public let shopName: String
    public let discountLimit: Double
    public let taxIsOn: Bool

    public init(saleRepository: SaleRepositoryProtocol, inventoryRepository: InventoryItemRepositoryProtocol,
                customerRepository: CustomerRepositoryProtocol, memberRepository: any OrgCollectionRepositoryProtocol<Member>,
                expenseRepository: any OrgCollectionRepositoryProtocol<Expense>,
                ledgerRepository: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>,
                cashflowRepository: CashflowTransactionRepositoryProtocol? = nil,
                categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)? = nil,
                shopName: String, discountLimit: Double = 10, taxIsOn: Bool = false) {
        self.saleRepository = saleRepository
        self.inventoryRepository = inventoryRepository
        self.customerRepository = customerRepository
        self.memberRepository = memberRepository
        self.expenseRepository = expenseRepository
        self.ledgerRepository = ledgerRepository
        self.cashflowRepository = cashflowRepository
        self.categoryRepository = categoryRepository
        self.shopName = shopName
        self.discountLimit = discountLimit
        self.taxIsOn = taxIsOn
    }

    public func load() async {
        sales = ((try? await saleRepository.getSales()) ?? []).filter { !$0.isCancelled }
        items = ((try? await inventoryRepository.getInventoryItems()) ?? []).filter { !$0.isDeleted }
        customers = ((try? await customerRepository.getCustomers()) ?? []).filter { !$0.isDeleted }
        members = (try? await memberRepository.all()) ?? []
        expenses = ((try? await expenseRepository.all()) ?? []).filter { !$0.isDeleted }
        ledger = ((try? await ledgerRepository.all()) ?? []).filter { !$0.isDeleted }
        transactions = ((try? await cashflowRepository?.getCashflowTransactions()) ?? []).filter { !$0.isDeleted }
        categories = (try? await categoryRepository?.all()) ?? []
    }

    // MARK: Period data

    private var ranges: (current: DateInterval, previous: DateInterval) { period.ranges() }
    public var periodSales: [Sale] { sales.filter { ranges.current.contains($0.timestamp) } }
    private var previousSales: [Sale] { sales.filter { ranges.previous.contains($0.timestamp) } }
    private var periodExpenses: [Expense] { expenses.filter { ranges.current.contains($0.date) } }

    public var metrics: ShopMetrics { ShopMetrics(sales: periodSales, items: items, expenses: periodExpenses) }

    public var trend: String? {
        let previous = previousSales.reduce(0) { $0 + $1.signedTotal }
        guard previous > 0 else { return nil }
        let change = Int(((metrics.revenue - previous) / previous * 100).rounded())
        return "\(change >= 0 ? "+" : "")\(change)%"
    }

    /// Sales per day (per 3 hours for Today) across the period, for the line chart.
    public var salesSeries: [Double] {
        let calendar = Calendar.current
        let range = ranges.current
        if period == .today {
            return (0..<8).map { slot in
                let start = range.start.addingTimeInterval(Double(slot) * 3 * 3600)
                let end = start.addingTimeInterval(3 * 3600)
                return periodSales.filter { $0.timestamp >= start && $0.timestamp < end }.reduce(0) { $0 + $1.signedTotal }
            }
        }
        var values: [Double] = []
        var day = range.start
        while day < range.end && day <= Date() {
            values.append(periodSales.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }.reduce(0) { $0 + $1.signedTotal })
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return values
    }

    public var newCustomers: Int {
        customers.filter { ranges.current.contains(Date(timeIntervalSince1970: $0.createdAt)) }.count
    }

    // MARK: Items (91)

    public var topCategories: [(name: String, amount: Double)] {
        let categoryOf = Dictionary(items.map { ($0.id, $0.categoryId) }, uniquingKeysWith: { first, _ in first })
        var totals: [String: Double] = [:]
        for item in metrics.topItems {
            guard let categoryId = categoryOf[item.id] ?? nil else { continue }
            totals[categoryId, default: 0] += item.amount
        }
        let named = totals.map { id, amount in (name: categories.first { $0.id == id }?.name ?? id, amount: amount) }
        return Array(named.sorted { $0.amount > $1.amount }.prefix(5))
    }

    public var bestSellers: [ShopMetrics.ItemTotal] { Array(metrics.topItems.prefix(5)) }

    /// In stock but not sold in 45 days.
    public var slowMovers: [InventoryItem] {
        let cutoff = Date().addingTimeInterval(-45 * 86_400)
        let soldRecently = Set(sales.filter { $0.timestamp >= cutoff }.flatMap(\.items).map(\.categoryId))
        return Array(items.filter { $0.currentStock > 0 && !soldRecently.contains($0.id) }
            .sorted { ($0.lastSoldDate ?? .distantPast) < ($1.lastSoldDate ?? .distantPast) }.prefix(8))
    }

    // MARK: Customers (92)

    private var buyersInPeriod: [String: [Sale]] {
        Dictionary(grouping: periodSales.filter { !$0.customerPhone.isEmpty && !$0.isReturn }, by: \.customerPhone)
    }

    public var repeatRate: Double {
        let buyers = buyersInPeriod
        guard !buyers.isEmpty else { return 0 }
        return Double(buyers.values.filter { $0.count >= 2 }.count) / Double(buyers.count)
    }

    public var averageVisits: Double {
        let buyers = buyersInPeriod
        return buyers.isEmpty ? 0 : Double(buyers.values.reduce(0) { $0 + $1.count }) / Double(buyers.count)
    }

    public var totalDues: Double { customers.reduce(0) { $0 + max(0, $1.dueBalance) } }

    /// Each customer's due, aged by their oldest unpaid credit entry.
    public var duesAgeing: [(label: String, amount: Double)] {
        var buckets: [Double] = [0, 0, 0, 0]
        let now = Date()
        for customer in customers where customer.dueBalance > 0 {
            let entries = ledger.filter { $0.customerPhone == customer.phone }.sorted { $0.createdAt < $1.createdAt }
            var running = 0.0
            var since: Date?
            for entry in entries {
                if running <= 0 && entry.amount > 0 { since = entry.createdAt }
                running += entry.amount
            }
            let days = since.map { Int(now.timeIntervalSince($0) / 86_400) } ?? 0
            let index = days <= 7 ? 0 : days <= 30 ? 1 : days <= 60 ? 2 : 3
            buckets[index] += customer.dueBalance
        }
        return zip(["0-7d", "8-30d", "31-60d", "60d+"], buckets).map { ($0, $1) }
    }

    public var topCustomers: [(name: String, visits: Int, amount: Double)] {
        var result: [(name: String, visits: Int, amount: Double)] = []
        for (phone, bills) in buyersInPeriod {
            let name: String = customers.first { $0.phone == phone }?.name ?? bills.first?.customerName ?? phone
            let amount: Double = bills.reduce(0) { $0 + $1.netPayable }
            result.append((name, bills.count, amount))
        }
        return Array(result.sorted { $0.amount > $1.amount }.prefix(5))
    }

    // MARK: Staff (93) and services (70)

    public func memberName(_ id: String) -> String {
        members.first { $0.id == id }?.name ?? (id.isEmpty ? "Unknown" : "Staff")
    }

    public var staffSales: [(id: String, name: String, bills: Int, amount: Double)] {
        Dictionary(grouping: periodSales, by: \.staffId).map { id, bills in
            (id, memberName(id), bills.filter { !$0.isReturn }.count, bills.reduce(0) { $0 + $1.signedTotal })
        }
        .sorted { $0.amount > $1.amount }
    }

    public var discountsAboveLimit: Int {
        periodSales.filter { $0.overallDiscountPercent > discountLimit + 0.001 }.count
    }

    public var serviceStaff: [(id: String, name: String, services: Int, amount: Double, commissionPercent: Double, commission: Double)] {
        var totals: [String: (services: Int, amount: Double)] = [:]
        for sale in periodSales where !sale.isReturn {
            for line in sale.items {
                guard let staffId = line.doneByStaffId else { continue }
                totals[staffId, default: (0, 0)].services += line.qty
                totals[staffId, default: (0, 0)].amount += line.totalAmount
            }
        }
        return totals.map { id, value in
            let percent = members.first { $0.id == id }?.commissionPercent ?? 0
            return (id, memberName(id), value.services, value.amount, percent, (value.amount * percent / 100).rounded())
        }
        .sorted { $0.amount > $1.amount }
    }

    // MARK: Profit (95)

    public var profitByWeek: [(label: String, amount: Double)] {
        let calendar = Calendar.current
        let range = ranges.current
        var result: [(String, Double)] = []
        var start = range.start
        var index = 1
        while start < range.end {
            let end = min(calendar.date(byAdding: .day, value: 7, to: start)!, range.end)
            let interval = DateInterval(start: start, end: end)
            let metrics = ShopMetrics(sales: periodSales.filter { interval.contains($0.timestamp) }, items: items,
                                      expenses: periodExpenses.filter { interval.contains($0.date) })
            result.append(("W\(index)", metrics.netProfit))
            start = end
            index += 1
        }
        return result
    }

    public var previousNetProfit: Double {
        ShopMetrics(sales: previousSales, items: items, expenses: expenses.filter { ranges.previous.contains($0.date) }).netProfit
    }

    // MARK: Reports (94)

    public enum Report: String, CaseIterable, Sendable {
        case sales = "Sales summary", items = "Item-wise sales", dues = "Customer dues", cashBook = "Cash book",
             staff = "Staff performance", tax = "Tax summary"

        public var subtitle: String {
            switch self {
            case .sales: "Day-wise totals by payment mode"
            case .items: "Quantity and value by item"
            case .dues: "Who owes what, ageing"
            case .cashBook: "All cash in and out"
            case .staff: "Bills, sales, discounts"
            case .tax: "Only when tax is on"
            }
        }
    }

    public func csv(for report: Report) -> String {
        func row(_ fields: [String]) -> String {
            fields.map { $0.contains(",") || $0.contains("\"") ? "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" : $0 }
                .joined(separator: ",")
        }
        func number(_ value: Double) -> String { String(format: "%.2f", value) }
        var lines: [String]
        switch report {
        case .sales:
            lines = [row(["Date", "Bills", "Cash", "UPI", "Card", "Credit", "Total"])]
            let byDay = Dictionary(grouping: periodSales, by: { $0.timestamp.dayKey })
            for day in byDay.keys.sorted(by: { (byDay[$0]?.first?.timestamp ?? .distantPast) < (byDay[$1]?.first?.timestamp ?? .distantPast) }) {
                let bills = byDay[day] ?? []
                lines.append(row([day, String(bills.filter { !$0.isReturn }.count)] + [PaymentMode.cash, .upi, .card, .credit].map { mode in
                    number(bills.reduce(0) { $0 + $1.paid(mode) })
                } + [number(bills.reduce(0) { $0 + $1.signedTotal })]))
            }
        case .items:
            lines = [row(["Item", "Quantity", "Amount"])] + metrics.topItems.map { row([$0.name, number($0.quantity), number($0.amount)]) }
        case .dues:
            lines = [row(["Customer", "Phone", "Due"])] + customers.filter { $0.dueBalance > 0 }.sorted { $0.dueBalance > $1.dueBalance }
                .map { row([$0.name, $0.phone, number($0.dueBalance)]) }
            lines += [""] + duesAgeing.map { row([$0.label, "", number($0.amount)]) }
        case .cashBook:
            lines = [row(["Date", "Particulars", "In", "Out", "Mode"])] + transactions.filter { ranges.current.contains($0.timestamp) }
                .sorted { $0.timestamp < $1.timestamp }
                .map { row([$0.timestamp.formatted(date: .numeric, time: .shortened), $0.particulars,
                            $0.transactionType == .credit ? number($0.amount) : "", $0.transactionType == .debit ? number($0.amount) : "",
                            $0.paymentMode.rawValue]) }
        case .staff:
            lines = [row(["Staff", "Bills", "Sales", "Discounts above limit"])] + staffSales.map { staff in
                row([staff.name, String(staff.bills), number(staff.amount),
                     String(periodSales.filter { $0.staffId == staff.id && $0.overallDiscountPercent > discountLimit + 0.001 }.count)])
            }
        case .tax:
            lines = [row(["Date", "Bill", "Total"])] + (taxIsOn ? periodSales.map { row([$0.timestamp.dayKey, $0.displayNumber, number($0.signedTotal)]) } : [])
        }
        return lines.joined(separator: "\n")
    }

    public func reportFile(_ report: Report) -> URL? {
        let name = "\(report.rawValue.replacingOccurrences(of: " ", with: "-"))-\(period.rawValue.replacingOccurrences(of: " ", with: "-")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        return (try? csv(for: report).write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
    }
}
