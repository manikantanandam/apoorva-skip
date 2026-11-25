//
//  CheckoutViewModel.swift
//  ApoorvaModules
//

import Foundation
import Observation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository
import ApoorvaServices

/// Checkout (design 42) and UPI (44) share this state.
@MainActor
@Observable
public class CheckoutViewModel {

    /// Mutable so checkout can change the customer without losing the entered payment amounts.
    public var cart: PosCart
    public let heldBillId: String?

    /// Amount typed against each payment mode. All empty means the whole bill is paid in cash.
    public var amountTexts: [PaymentMode: String] = [:]
    /// Chip whose amount box is showing; switching it keeps what was typed for the others.
    public var selectedMode: PaymentMode = .cash
    public var roundOffEnabled: Bool
    public var isProcessing: Bool = false
    public var errorMessage: String?

    // Kept for existing call sites.
    public var overallDiscountPercent: Double { cart.discountPercent ?? (subtotal > 0 ? cart.flatDiscount / subtotal * 100 : 0) }

    private let saleRepository: SaleRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let lifecycle: SaleLifecycleRepositoryProtocol?
    private let session: AppSession?
    private let analyticsService: AnalyticsServicing
    private let performanceMonitoringService: PerformanceMonitoringServicing
    private var didLogBeginCheckout = false

    public init(
        cart: PosCart,
        heldBillId: String?,
        saleRepository: SaleRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        lifecycle: SaleLifecycleRepositoryProtocol? = nil,
        session: AppSession? = nil,
        analyticsService: AnalyticsServicing = NoOpAnalyticsService(),
        performanceMonitoringService: PerformanceMonitoringServicing = NoOpPerformanceMonitoringService()
    ) {
        self.cart = cart
        self.heldBillId = heldBillId
        self.saleRepository = saleRepository
        self.userRepository = userRepository
        self.lifecycle = lifecycle
        self.session = session
        self.roundOffEnabled = session?.settings.payments.roundOff ?? true
        self.analyticsService = analyticsService
        self.performanceMonitoringService = performanceMonitoringService
    }

    // MARK: - Totals

    public var itemCount: Int { cart.totalItemsCount }
    public var totalMRP: Double { cart.totalMRP }
    public var itemDiscounts: Double { cart.totalDiscountOnMRP }
    public var subtotal: Double { cart.totalFinalPrice }
    public var overallDiscountAmount: Double { cart.flatDiscount }

    /// Rounds the payable to the nearest rupee when on (shown as "Round off").
    public var roundOff: Double {
        guard roundOffEnabled else { return 0 }
        let raw = subtotal - overallDiscountAmount
        return raw - raw.rounded()
    }

    public var finalTotal: Double { max(subtotal - overallDiscountAmount - roundOff, 0) }

    public var enabledModes: [PaymentMode] {
        let allowed = Set(session?.settings.payments.enabledModes ?? PaymentMode.allCases.map(\.rawValue))
        var modes = [PaymentMode.cash, .upi, .card, .credit].filter { allowed.contains($0.rawValue) }
        if session?.isOn(.creditSales) == false || session?.can(.creditSales) == false { modes.removeAll { $0 == .credit } }
        return modes
    }

    // MARK: - Payment amounts

    /// Positive amounts typed per mode.
    private var enteredAmounts: [PaymentMode: Double] {
        amountTexts.compactMapValues { text in Double(text).flatMap { $0 > 0 ? $0 : nil } }
    }

    /// Cash typed in the cash box, to work out change; nil when nothing was typed.
    public var cashReceived: Double? { enteredAmounts[.cash] }

    /// What is actually recorded per mode. Nothing typed = the whole bill in cash. Cash typed above
    /// what the other modes leave to pay is treated as tendered cash, so only the due part is recorded.
    public var payments: [PaymentMode: Double] {
        let entered = enteredAmounts
        if entered.isEmpty { return [.cash: finalTotal] }
        var result = entered
        if let cash = entered[.cash] {
            let others = entered.filter { $0.key != .cash }.values.reduce(0, +)
            if others < finalTotal { result[.cash] = min(cash, finalTotal - others) }
        }
        return result
    }

    public var activeModes: [PaymentMode] { Array(payments.keys) }

    public var paid: Double { payments.values.reduce(0, +) }
    public var remaining: Double { max(0, finalTotal - paid) }
    /// Typed amounts add up to more than the bill (cash over-tender is not counted).
    public var overpaid: Double { max(0, paid - finalTotal) }

    public var changeDue: Double {
        guard let cash = cashReceived else { return 0 }
        return max(0, cash - (payments[.cash] ?? 0))
    }

    /// Credit needs a customer to owe the money.
    public var creditNeedsCustomer: Bool {
        (payments[.credit] ?? 0) > 0 && (cart.customerPhone ?? "").isEmpty
    }

    public var isSettled: Bool {
        !creditNeedsCustomer && abs(paid - finalTotal) < 0.5
    }

    /// Any UPI amount goes through the QR screen first.
    public var requiresUPIConfirmation: Bool { upiAmount > 0 }

    /// The UPI part of the bill, shown on the QR screen.
    public var upiAmount: Double { payments[.upi] ?? 0 }

    public var upiId: String { session?.settings.payments.upiId ?? "" }
    public var payeeName: String { session?.displayShopName ?? "Apoorva" }

    /// Writes the sale (local + Firestore), bumps the customer, clears the held bill, then records
    /// stock and dues. Returns the sale for the receipt.
    /// Logs `begin_checkout` once per checkout, even when the screen reappears after the UPI QR step.
    public func checkoutStarted() {
        guard !didLogBeginCheckout else { return }
        didLogBeginCheckout = true
        analyticsService.log(.beginCheckout(value: finalTotal, itemCount: cart.items.count))
    }

    public func confirmSale() async -> Sale? {
        guard isSettled else {
            if creditNeedsCustomer { errorMessage = "Add a customer to sell on credit." }
            return nil
        }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let user = try await userRepository.getCurrentUser()
            let staffId = session?.actorId.isEmpty == false ? session!.actorId : user.id
            let billNumber = await session?.nextBillNumber()
            let sale = Sale(
                id: UUID().uuidString,
                staffId: staffId,
                customerPhone: cart.customerPhone ?? "",
                customerName: cart.customerName?.isEmpty == false ? cart.customerName! : "Walk-in",
                items: cart.items.map(SaleItem.init(cartItem:)),
                subtotal: subtotal,
                overallDiscountPercent: overallDiscountPercent,
                overallDiscountAmount: overallDiscountAmount,
                roundOff: roundOff,
                netPayable: finalTotal,
                payments: payments,
                timestamp: cart.billDateTime,
                source: "POS",
                status: "Completed",
                whatsappStatus: "unsent",
                storeId: session?.currentStoreId,
                billNumber: billNumber,
                returnOfSaleId: cart.returnOfSaleId
            )

            try await performanceMonitoringService.measure("save_bill") {
                try await saleRepository.confirmSale(sale, heldBillId: heldBillId)
                // Stock out and credit dues; a failure here mustn't lose the confirmed sale.
                try? await lifecycle?.recordEffects(of: sale, by: staffId)
            }
            await session?.refreshPlanUsage()
            let modes = activeModes.map(\.title).sorted().joined(separator: "+")
            analyticsService.log(.billSaved(itemCount: sale.items.count, mode: modes))
            if let originalId = sale.returnOfSaleId {
                analyticsService.log(.refund(transactionId: originalId, value: abs(sale.netPayable), reason: "return"))
            } else {
                analyticsService.log(.purchase(transactionId: sale.id, value: sale.netPayable, discount: overallDiscountAmount,
                                               itemCount: sale.items.count, paymentType: modes))
            }
            return sale
        } catch {
            errorMessage = "Couldn't confirm this sale. Please try again."
            return nil
        }
    }
}
