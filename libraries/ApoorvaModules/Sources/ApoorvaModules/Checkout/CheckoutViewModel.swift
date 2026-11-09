//
//  CheckoutViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class CheckoutViewModel {

    public let cart: PosCart
    public let heldBillId: String?

    public var overallDiscountPercent: Double = 0 {
        didSet { syncSinglePaymentMode() }
    }
    public var roundOffText: String = "0" {
        didSet { syncSinglePaymentMode() }
    }
    public var selectedModes: [PaymentMode: Bool] = [.cash: true]
    public var amountTexts: [PaymentMode: String] = [:]
    public var isProcessing: Bool = false
    public var errorMessage: String?

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
        syncSinglePaymentMode()
    }

    // MARK: - Bill math (mirrors `Sale`'s own computed properties)

    public var totalMRP: Double { cart.totalMRP }
    public var itemDiscounts: Double { cart.totalDiscountOnMRP }
    public var subtotal: Double { cart.totalFinalPrice }
    public var overallDiscountAmount: Double { subtotal * overallDiscountPercent / 100 }
    public var roundOff: Double { Double(roundOffText) ?? 0 }
    public var finalTotal: Double {
        max(subtotal - overallDiscountAmount - roundOff, 0)
    }

    public var activeModes: [PaymentMode] {
        PaymentMode.allCases.filter { selectedModes[$0] == true }
    }

    public var totalPaid: Double {
        activeModes.reduce(0) { $0 + (Double(amountTexts[$1] ?? "") ?? 0) }
    }

    public var balance: Double {
        finalTotal - totalPaid
    }

    public var isSettled: Bool {
        !activeModes.isEmpty && abs(balance) < 0.5
    }

    /// Checkout detours through the UPI QR placeholder screen before finalizing only
    /// when UPI is the sole active payment mode.
    public var requiresUPIConfirmation: Bool {
        activeModes == [.upi]
    }

    public func setDiscount(_ percent: Double) {
        overallDiscountPercent = percent
    }

    public func toggleMode(_ mode: PaymentMode, isOn: Bool) {
        selectedModes[mode] = isOn
        if !isOn {
            amountTexts[mode] = nil
        }
        syncSinglePaymentMode()
    }

    public func amountBinding(for mode: PaymentMode) -> Binding<String> {
        Binding(
            get: { self.amountTexts[mode] ?? "" },
            set: { self.amountTexts[mode] = $0 }
        )
    }

    /// Ports Flutter's `_autoSyncPayment`: when exactly one mode is active, its amount
    /// always tracks the current total so the user doesn't have to type it by hand.
    private func syncSinglePaymentMode() {
        guard activeModes.count == 1, let mode = activeModes.first else { return }
        amountTexts[mode] = finalTotal.moneyString
    }

    /// Writes the sale (local + Firestore), bumps the customer's stats, and clears the
    /// held bill it came from, if any. Returns the confirmed `Sale` for the receipt screen.
    public func confirmSale() async -> Sale? {
        guard isSettled else { return nil }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let user = try await userRepository.getCurrentUser()
            var payments: [PaymentMode: Double] = [:]
            for mode in activeModes {
                payments[mode] = Double(amountTexts[mode] ?? "") ?? 0
            }

            let saleItems = cart.items.map { item in
                SaleItem(
                    categoryId: item.category.id,
                    categoryName: item.category.name,
                    qty: item.quantity,
                    stickerPrice: item.mrp,
                    finalPrice: item.finalPrice,
                    discountType: item.discountType
                )
            }

            let staffId = session?.actorId.isEmpty == false ? session!.actorId : user.id
            let billNumber = await session?.nextBillNumber()
            let sale = Sale(
                id: UUID().uuidString,
                staffId: staffId,
                customerPhone: cart.customerPhone ?? "",
                customerName: cart.customerName?.isEmpty == false ? cart.customerName! : "Walk-in",
                items: saleItems,
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
                billNumber: billNumber
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
