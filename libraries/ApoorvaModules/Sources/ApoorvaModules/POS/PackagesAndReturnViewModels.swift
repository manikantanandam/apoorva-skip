//
//  PackagesAndReturnViewModels.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

/// Parlour packages & memberships (design 39).
@MainActor
@Observable
public final class PackagesViewModel {
    public private(set) var catalog: [ServicePackage] = []
    public private(set) var owned: [CustomerPackage] = []
    public var errorMessage: String?

    public let customerPhone: String?
    public let customerName: String
    private let packages: any OrgCollectionRepositoryProtocol<ServicePackage>
    private let customerPackages: any OrgCollectionRepositoryProtocol<CustomerPackage>
    private let audit: AuditLogging?

    public init(customerPhone: String?, customerName: String,
                packages: any OrgCollectionRepositoryProtocol<ServicePackage>,
                customerPackages: any OrgCollectionRepositoryProtocol<CustomerPackage>,
                audit: AuditLogging? = nil) {
        self.customerPhone = customerPhone?.isEmpty == true ? nil : customerPhone
        self.customerName = customerName
        self.packages = packages
        self.customerPackages = customerPackages
        self.audit = audit
    }

    public func load() async {
        catalog = ((try? await packages.all()) ?? []).sorted { $0.price < $1.price }
        guard let customerPhone else { owned = []; return }
        owned = ((try? await customerPackages.all()) ?? [])
            .filter { $0.customerPhone == customerPhone }
            .sorted { $0.isActive && !$1.isActive || ($0.isActive == $1.isActive && $0.purchasedAt > $1.purchasedAt) }
    }

    public var firstActive: CustomerPackage? { owned.first(where: \.isActive) }

    /// A bill line for selling this package; the purchase is recorded once the bill is saved.
    public func cartLine(for package: ServicePackage) -> CartItem {
        CartItem(category: InventoryItem(id: "package:\(package.id)", name: package.name, sellPrice: package.price),
                 mrp: package.price, quantity: 1, lineId: "package:\(package.id)")
    }

    /// Uses one session today. Returns false when nothing is left.
    @discardableResult
    public func useSession(_ package: CustomerPackage) async -> Bool {
        guard package.isActive, package.sessions == 0 || package.sessionsLeft > 0 else {
            errorMessage = "No sessions left on \(package.name)."
            return false
        }
        var updated = package
        updated.sessionsUsed += 1
        do {
            try await customerPackages.save(updated)
            await audit?.log(.bills, action: "package.use",
                             summary: "\(customerName) used 1 session of \(package.name) (\(updated.sessionsUsed)/\(package.sessions))",
                             targetId: package.id)
            await load()
            return true
        } catch {
            errorMessage = "Couldn't record the session. Try again."
            return false
        }
    }

    /// After a bill is saved: turns every "package:" line into a customer package.
    public static func recordPurchases(in sale: Sale,
                                       packages: any OrgCollectionRepositoryProtocol<ServicePackage>,
                                       customerPackages: any OrgCollectionRepositoryProtocol<CustomerPackage>) async {
        let ids = sale.items.compactMap { $0.categoryId.hasPrefix("package:") ? String($0.categoryId.dropFirst(8)) : nil }
        guard !ids.isEmpty, !sale.customerPhone.isEmpty else { return }
        let catalog = (try? await packages.all()) ?? []
        for id in ids {
            guard let package = catalog.first(where: { $0.id == id }) else { continue }
            try? await customerPackages.save(CustomerPackage(package: package, customerPhone: sale.customerPhone,
                                                            customerName: sale.customerName, purchasedAt: sale.timestamp,
                                                            saleId: sale.id))
        }
    }
}

/// Return / exchange from a past bill (design 52).
@MainActor
@Observable
public final class ReturnViewModel {
    public enum Refund: String, CaseIterable, Sendable {
        case cash = "Refund cash", storeCredit = "Store credit", exchange = "Exchange"
    }

    public struct Line: Identifiable, Sendable {
        public let id: String
        public let item: SaleItem
        public var returnQty: Int
        public var isSelected: Bool { returnQty > 0 }
        public var amount: Double { Double(returnQty) * item.finalPrice }
    }

    public let saleId: String
    public private(set) var sale: Sale?
    public var lines: [Line] = []
    public var reason = ""
    public var refund: Refund = .cash
    public var isProcessing = false
    public var errorMessage: String?

    private let saleRepository: SaleRepositoryProtocol
    private let lifecycle: SaleLifecycleRepositoryProtocol
    private let session: AppSession?

    public init(saleId: String, saleRepository: SaleRepositoryProtocol, lifecycle: SaleLifecycleRepositoryProtocol,
                session: AppSession? = nil) {
        self.saleId = saleId
        self.saleRepository = saleRepository
        self.lifecycle = lifecycle
        self.session = session
    }

    public func load() async {
        sale = try? await saleRepository.getSale(id: saleId)
        lines = sale?.items.map { Line(id: $0.id, item: $0, returnQty: 0) } ?? []
    }

    public var refundAmount: Double { lines.reduce(0) { $0 + $1.amount } }

    /// Store credit needs a customer to hold the credit.
    public var availableRefunds: [Refund] {
        (sale?.customerPhone ?? "").isEmpty ? [.cash, .exchange] : Refund.allCases
    }

    public var canProcess: Bool {
        refundAmount > 0 && !reason.trimmingCharacters(in: .whitespaces).isEmpty && !(sale?.isCancelled ?? true)
    }

    public func toggle(_ id: String) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].returnQty = lines[index].isSelected ? 0 : lines[index].item.qty
    }

    public func setQty(_ qty: Int, for id: String) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].returnQty = min(max(0, qty), lines[index].item.qty)
    }

    /// For an exchange: the returned lines as negative cart lines, so the new bill nets them off.
    public func exchangeCart() -> PosCart {
        let billLabel = sale?.billNumber ?? String(saleId.prefix(6))
        let items = lines.filter(\.isSelected).map { line in
            CartItem(category: InventoryItem(id: line.item.categoryId, name: "Return · \(line.item.categoryName) (\(billLabel))"),
                     mrp: line.item.finalPrice, quantity: -line.returnQty, lineId: "return:\(line.id)")
        }
        return PosCart(items: items,
                       customerPhone: sale?.customerPhone.isEmpty == false ? sale?.customerPhone : nil,
                       customerName: sale?.customerName == "Walk-in" ? nil : sale?.customerName)
    }

    /// Cash or store-credit return: saves a return bill linked to the original and puts stock back.
    public func process() async -> Sale? {
        guard canProcess, let original = sale, refund != .exchange else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        let actor = session?.actorId.isEmpty == false ? session!.actorId : original.staffId
        let items = lines.filter(\.isSelected).map { line in
            SaleItem(categoryId: line.item.categoryId, categoryName: line.item.categoryName, qty: line.returnQty,
                     stickerPrice: line.item.stickerPrice, finalPrice: line.item.finalPrice, discountType: line.item.discountType)
        }
        var returnSale = Sale(id: UUID().uuidString, staffId: actor,
                              customerPhone: original.customerPhone, customerName: original.customerName,
                              items: items, subtotal: refundAmount, overallDiscountPercent: 0, overallDiscountAmount: 0,
                              roundOff: 0, netPayable: refundAmount,
                              payments: [refund == .storeCredit ? .credit : .cash: refundAmount],
                              timestamp: Date(), source: "Return", status: "Completed", whatsappStatus: "unsent",
                              storeId: original.storeId, billNumber: await session?.nextBillNumber(),
                              returnOfSaleId: original.id)
        returnSale.editReason = reason
        do {
            try await saleRepository.confirmSale(returnSale, heldBillId: nil)
            try? await lifecycle.recordEffects(of: returnSale, by: actor)
            return returnSale
        } catch {
            errorMessage = "Couldn't save the return. Try again."
            return nil
        }
    }
}
