//
//  SellViewModels.swift
//  ApoorvaModules
//
//  Orders list (58), new order (59), order detail (60), warranty lookup & claims (63).
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

// MARK: - Orders list (58)

@MainActor
@Observable
public final class OrdersViewModel {
    public private(set) var orders: [Order] = []
    public var status: OrderStatus = .open

    private let repository: any OrgCollectionRepositoryProtocol<Order>

    public init(repository: any OrgCollectionRepositoryProtocol<Order>) {
        self.repository = repository
    }

    public func load() async {
        orders = ((try? await repository.all()) ?? []).filter { !$0.isDeleted }
    }

    public var visible: [Order] {
        orders.filter { $0.status == status }
            .sorted { status == .open || status == .ready ? $0.readyBy < $1.readyBy : $0.createdAt > $1.createdAt }
    }

    public var openCount: Int { orders.filter { $0.status == .open || $0.status == .ready }.count }
    public var advanceHeld: Double { orders.filter { $0.status == .open || $0.status == .ready }.reduce(0) { $0 + $1.advance } }

    public var subtitle: String {
        advanceHeld > 0 ? "\(openCount) open · \(Money.format(advanceHeld)) advance held" : "\(openCount) open"
    }
}

// MARK: - New order (59)

@MainActor
@Observable
public final class OrderFormViewModel {
    public enum ReadyBy: String, CaseIterable, Sendable { case tomorrow = "Tomorrow", threeDays = "In 3 days", pick = "Pick date" }

    public var customerPhone = ""
    public var customerName = ""
    public var details = ""
    public var totalText = ""
    public var advanceText = ""
    public var advanceMode: PaymentMode = .upi
    public var readyByChoice: ReadyBy = .threeDays
    public var pickedDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    public var fulfilment: OrderFulfilment = .pickup
    public var notifyWhenReady = true
    public var isSaving = false
    public var errorMessage: String?
    public private(set) var matches: [Customer] = []

    private var customers: [Customer] = []
    private let orders: any OrgCollectionRepositoryProtocol<Order>
    private let customerRepository: CustomerRepositoryProtocol
    private let dues: DuesRepositoryProtocol
    private let audit: AuditLogging?
    private let actorId: String
    private let actorName: String

    public init(orders: any OrgCollectionRepositoryProtocol<Order>, customerRepository: CustomerRepositoryProtocol,
                dues: DuesRepositoryProtocol, audit: AuditLogging?, actorId: String, actorName: String) {
        self.orders = orders
        self.customerRepository = customerRepository
        self.dues = dues
        self.audit = audit
        self.actorId = actorId
        self.actorName = actorName
    }

    public func load() async {
        customers = (try? await customerRepository.getCustomers()) ?? []
    }

    /// Suggests existing customers as the phone or name is typed.
    public func updateMatches() {
        let digits = customerPhone.filter(\.isNumber)
        guard digits.count >= 3 || customerName.count >= 2 else { matches = []; return }
        matches = Array(customers.filter {
            (digits.count >= 3 && $0.phone.contains(digits)) || (customerName.count >= 2 && $0.name.localizedCaseInsensitiveContains(customerName))
        }.prefix(3))
    }

    public func pick(_ customer: Customer) {
        customerPhone = customer.phone
        customerName = customer.name
        matches = []
    }

    public var total: Double { Double(totalText) ?? 0 }
    public var advance: Double { min(Double(advanceText) ?? 0, total) }
    public var balance: Double { max(0, total - advance) }

    public var readyBy: Date {
        let today = Calendar.current.startOfDay(for: Date())
        switch readyByChoice {
        case .tomorrow: return Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        case .threeDays: return Calendar.current.date(byAdding: .day, value: 3, to: today) ?? today
        case .pick: return pickedDate
        }
    }

    public var canSave: Bool {
        PhoneNumber.normalize(customerPhone).count == 10 && !customerName.trimmingCharacters(in: .whitespaces).isEmpty
            && !details.trimmingCharacters(in: .whitespaces).isEmpty && total > 0
    }

    public func save() async -> Order? {
        guard canSave else {
            errorMessage = "Add the customer, what to make and the total."
            return nil
        }
        isSaving = true
        defer { isSaving = false }
        let existing = (try? await orders.all()) ?? []
        let phone = PhoneNumber.normalize(customerPhone)
        let order = Order(number: String(format: "O-%04d", existing.count + 1), customerPhone: phone,
                          customerName: customerName.trimmingCharacters(in: .whitespaces),
                          details: details.trimmingCharacters(in: .whitespaces), total: total, advance: advance,
                          advanceMode: advanceMode.rawValue, readyBy: readyBy, fulfilment: fulfilment,
                          notifyWhenReady: notifyWhenReady, createdBy: actorId, createdByName: actorName)
        do {
            try await orders.save(order)
            if (try? await customerRepository.getCustomer(phone: phone)) == nil {
                let now = Date().timeIntervalSince1970
                try? await customerRepository.saveCustomer(customer: Customer(name: order.customerName, phone: phone, createdAt: now,
                                                                              lastPurchaseDate: nil, totalSales: 0, totalAmountSpent: 0,
                                                                              updatedAt: now, isDeleted: false))
            }
            try? await dues.recordCashIn(amount: advance, mode: advanceMode,
                                         particulars: "Advance · order \(order.number) · \(order.customerName)",
                                         person: order.customerName, at: Date())
            await audit?.log(.bills, action: "order.create",
                             summary: "Order \(order.number) for \(order.customerName) · \(Money.format(total)), advance \(Money.format(advance))",
                             targetId: order.id)
            return order
        } catch {
            errorMessage = "Couldn't save the order. Try again."
            return nil
        }
    }
}

// MARK: - Order detail (60)

@MainActor
@Observable
public final class OrderDetailViewModel {
    public let orderId: String
    public private(set) var order: Order?
    public var errorMessage: String?

    private let repository: any OrgCollectionRepositoryProtocol<Order>
    private let audit: AuditLogging?
    private let shopName: String

    public init(orderId: String, repository: any OrgCollectionRepositoryProtocol<Order>, audit: AuditLogging?, shopName: String) {
        self.orderId = orderId
        self.repository = repository
        self.audit = audit
        self.shopName = shopName
    }

    public func load() async {
        order = try? await repository.get(id: orderId)
    }

    public var readyMessage: String {
        guard let order else { return "" }
        var text = "Hi \(order.customerName), your order \(order.number) (\(order.details)) is ready"
        text += order.fulfilment == .delivery ? " and will be delivered soon." : " for pickup at \(shopName)."
        if order.balance > 0 { text += " Balance: \(Money.format(order.balance))." }
        return text + " Thank you!"
    }

    public var readyMessageURL: URL? {
        order.flatMap { MessageLink.whatsApp(to: $0.customerPhone, text: readyMessage) }
    }

    public func markReady() async {
        await update(action: "order.ready") { $0.status = .ready; $0.readyAt = Date() }
    }

    public func cancel() async {
        await update(action: "order.cancel") { $0.status = .cancelled }
    }

    /// The bill for delivery: one line for the balance, tagged so the order closes once it's saved.
    public func deliveryCart() -> PosCart? {
        guard let order else { return nil }
        let item = InventoryItem(id: OrderDeliveries.lineId(for: order), name: "Order \(order.number) · \(order.details)",
                                 sellPrice: order.balance)
        return PosCart(items: [CartItem(category: item, mrp: order.balance, quantity: 1, lineId: item.id)],
                       customerPhone: order.customerPhone, customerName: order.customerName)
    }

    private func update(action: String, _ change: (inout Order) -> Void) async {
        guard var order else { return }
        change(&order)
        order.updatedAt = Date()
        do {
            try await repository.save(order)
            self.order = order
            await audit?.log(.bills, action: action, summary: "\(action.split(separator: ".").last ?? "") \(order.number)", targetId: order.id)
        } catch {
            errorMessage = "Couldn't update the order. Try again."
        }
    }
}

/// Closes orders whose balance was billed at the POS.
public enum OrderDeliveries {
    static let prefix = "custom-order-"

    public static func lineId(for order: Order) -> String { prefix + order.id }

    public static func markDelivered(in sale: Sale, repository: any OrgCollectionRepositoryProtocol<Order>,
                                     audit: AuditLogging?) async {
        let ids = sale.items.compactMap { $0.categoryId.hasPrefix(prefix) ? String($0.categoryId.dropFirst(prefix.count)) : nil }
        for id in ids {
            guard var order = try? await repository.get(id: id), order.status != .delivered else { continue }
            order.status = .delivered
            order.deliveredAt = sale.timestamp
            order.saleId = sale.id
            order.updatedAt = Date()
            try? await repository.save(order)
            await audit?.log(.bills, action: "order.deliver", summary: "Delivered \(order.number) on bill \(sale.displayNumber)",
                             targetId: order.id)
        }
    }
}

// MARK: - Warranty (63)

@MainActor
@Observable
public final class WarrantyViewModel {
    public struct Line: Identifiable, Sendable {
        public let id: String
        public let sale: Sale
        public let item: SaleItem
        public let months: Int
        public let until: Date
        public var isActive: Bool { until >= Calendar.current.startOfDay(for: Date()) }
    }

    public var query = ""
    public private(set) var lines: [Line] = []
    public private(set) var claims: [WarrantyClaim] = []
    public var selected: Line?
    public var action: WarrantyAction = .replace
    public var note = ""
    public var errorMessage: String?

    private var sales: [Sale] = []
    private let saleRepository: SaleRepositoryProtocol
    private let claimRepository: any OrgCollectionRepositoryProtocol<WarrantyClaim>
    private let audit: AuditLogging?
    private let actorId: String

    public init(saleRepository: SaleRepositoryProtocol, claimRepository: any OrgCollectionRepositoryProtocol<WarrantyClaim>,
                audit: AuditLogging?, actorId: String) {
        self.saleRepository = saleRepository
        self.claimRepository = claimRepository
        self.audit = audit
        self.actorId = actorId
    }

    public func load() async {
        sales = ((try? await saleRepository.getSales()) ?? []).filter { !$0.isCancelled && !$0.isReturn }
        claims = (try? await claimRepository.all()) ?? []
        search()
    }

    /// Lines with a warranty, matched by phone or bill number; the most recent first.
    public func search() {
        let text = query.trimmingCharacters(in: .whitespaces)
        let digits = PhoneNumber.normalize(text)
        let matched = text.isEmpty ? Array(sales.sorted { $0.timestamp > $1.timestamp }.prefix(30)) : sales.filter {
            (digits.count >= 4 && $0.customerPhone.contains(digits)) || $0.displayNumber.localizedCaseInsensitiveContains(text)
        }
        lines = matched.flatMap { sale in
            sale.items.compactMap { item -> Line? in
                guard let months = item.warrantyMonths, months > 0,
                      let until = Calendar.current.date(byAdding: .month, value: months, to: sale.timestamp) else { return nil }
                return Line(id: "\(sale.id)#\(item.id)", sale: sale, item: item, months: months, until: until)
            }
        }
        .sorted { $0.sale.timestamp > $1.sale.timestamp }
        if let selected, !lines.contains(where: { $0.id == selected.id }) { self.selected = nil }
    }

    public func claims(for line: Line) -> [WarrantyClaim] {
        claims.filter { $0.saleId == line.sale.id && $0.itemId == line.item.categoryId }
    }

    public var canClaim: Bool { selected?.isActive == true && !note.trimmingCharacters(in: .whitespaces).isEmpty }

    public func recordClaim() async -> Bool {
        guard canClaim, let line = selected else { return false }
        let claim = WarrantyClaim(saleId: line.sale.id, billNumber: line.sale.displayNumber, itemId: line.item.categoryId,
                                  itemName: line.item.categoryName, customerPhone: line.sale.customerPhone, action: action,
                                  note: note.trimmingCharacters(in: .whitespaces), createdBy: actorId)
        do {
            try await claimRepository.save(claim)
            claims.append(claim)
            await audit?.log(.bills, action: "warranty.claim",
                             summary: "\(action.title) · \(line.item.categoryName) · bill \(line.sale.displayNumber)", targetId: claim.id)
            note = ""
            return true
        } catch {
            errorMessage = "Couldn't save the claim. Try again."
            return false
        }
    }
}
