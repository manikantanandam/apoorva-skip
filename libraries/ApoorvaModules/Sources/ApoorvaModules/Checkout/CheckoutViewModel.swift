//
//  CheckoutViewModel.swift
//  ApoorvaModules
//

import Foundation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository

public enum CheckoutMode: String, CaseIterable, Sendable {
    case cash = "Cash", upi = "UPI", card = "Card", credit = "Credit", split = "Split"

    var paymentMode: PaymentMode? {
        switch self {
        case .cash: .cash
        case .upi: .upi
        case .card: .card
        case .credit: .credit
        case .split: nil
        }
    }
}

/// Checkout (design 42), split payment (43) and UPI (44) share this state.
@MainActor
@Observable
public class CheckoutViewModel {

    /// Mutable so checkout can change the customer without losing the chosen payment mode.
    public var cart: PosCart
    public let heldBillId: String?

    public var mode: CheckoutMode = .cash
    /// Cash handed over, to work out change (optional).
    public var cashReceivedText = ""
    /// Split amounts by mode (design 43).
    public var splitAmounts: [PaymentMode: Double] = [:]
    public var splitEntryMode: PaymentMode = .cash
    public var splitEntryText = ""
    public var roundOffEnabled: Bool
    public var isProcessing: Bool = false
    public var errorMessage: String?

    // Kept for existing call sites.
    public var overallDiscountPercent: Double { cart.discountPercent ?? (subtotal > 0 ? cart.flatDiscount / subtotal * 100 : 0) }

    private let saleRepository: SaleRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let lifecycle: SaleLifecycleRepositoryProtocol?
    private let session: AppSession?

    public init(
        cart: PosCart,
        heldBillId: String?,
        saleRepository: SaleRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        lifecycle: SaleLifecycleRepositoryProtocol? = nil,
        session: AppSession? = nil
    ) {
        self.cart = cart
        self.heldBillId = heldBillId
        self.saleRepository = saleRepository
        self.userRepository = userRepository
        self.lifecycle = lifecycle
        self.session = session
        self.roundOffEnabled = session?.settings.payments.roundOff ?? true
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

    public var enabledModes: [CheckoutMode] {
        let allowed = Set(session?.settings.payments.enabledModes ?? PaymentMode.allCases.map(\.rawValue))
        var modes = CheckoutMode.allCases.filter { mode in
            guard let payment = mode.paymentMode else { return true }
            return allowed.contains(payment.rawValue)
        }
        if session?.isOn(.splitPayment) == false { modes.removeAll { $0 == .split } }
        if session?.isOn(.creditSales) == false || session?.can(.creditSales) == false { modes.removeAll { $0 == .credit } }
        return modes
    }

    /// Credit needs a customer to owe the money.
    public var creditNeedsCustomer: Bool {
        (mode == .credit || (splitAmounts[.credit] ?? 0) > 0) && (cart.customerPhone ?? "").isEmpty
    }

    public var cashReceived: Double? {
        mode == .cash ? Double(cashReceivedText) : nil
    }

    public var changeDue: Double {
        guard mode == .cash, let received = Double(cashReceivedText) else { return 0 }
        return max(0, received - finalTotal)
    }

    // MARK: - Split

    public var splitPaid: Double { splitAmounts.values.reduce(0, +) }
    public var splitRemaining: Double { max(0, finalTotal - splitPaid) }

    public func splitKey(_ key: String) {
        switch key {
        case "⌫": splitEntryText = String(splitEntryText.dropLast())
        case ".": if !splitEntryText.contains(".") { splitEntryText += "." }
        default: if splitEntryText.count < 8 { splitEntryText += key }
        }
    }

    /// Records the typed amount (or the remainder, if nothing typed) against the current mode.
    public func confirmSplitEntry() {
        let amount = Double(splitEntryText) ?? splitRemaining
        guard amount > 0 else { return }
        splitAmounts[splitEntryMode] = (splitAmounts[splitEntryMode] ?? 0) + min(amount, splitRemaining)
        splitEntryText = ""
        if let next = [PaymentMode.cash, .upi, .card, .credit].first(where: { splitAmounts[$0] == nil }) {
            splitEntryMode = next
        }
    }

    public func clearSplit(_ mode: PaymentMode) {
        splitAmounts[mode] = nil
    }

    // MARK: - Settlement

    public var payments: [PaymentMode: Double] {
        if mode == .split { return splitAmounts.filter { $0.value > 0 } }
        return [mode.paymentMode ?? .cash: finalTotal]
    }

    public var activeModes: [PaymentMode] { Array(payments.keys) }

    public var isSettled: Bool {
        if creditNeedsCustomer { return false }
        if mode == .split { return abs(splitRemaining) < 0.5 && !splitAmounts.isEmpty }
        return true
    }

    /// UPI alone goes through the QR screen first.
    public var requiresUPIConfirmation: Bool { mode == .upi }

    public var upiId: String { session?.settings.payments.upiId ?? "" }
    public var payeeName: String { session?.displayShopName ?? "Apoorva" }

    /// Writes the sale (local + Firestore), bumps the customer, clears the held bill, then records
    /// stock and dues. Returns the sale for the receipt.
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

            try await saleRepository.confirmSale(sale, heldBillId: heldBillId)
            // Stock out and credit dues; a failure here mustn't lose the confirmed sale.
            try? await lifecycle?.recordEffects(of: sale, by: staffId)
            await session?.refreshPlanUsage()
            return sale
        } catch {
            errorMessage = "Couldn't confirm this sale. Please try again."
            return nil
        }
    }
}
