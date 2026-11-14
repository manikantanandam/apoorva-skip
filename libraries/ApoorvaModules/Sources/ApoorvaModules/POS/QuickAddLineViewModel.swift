//
//  QuickAddLineViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels

/// How the quick-add sheet reads its discount field.
public enum QuickDiscountMode: String, CaseIterable, Sendable {
    case finalPrice = "Final ₹"
    case percent = "% Off"
    case amount = "₹ Discount"

    public var fieldLabel: String {
        switch self {
        case .finalPrice: "Final price per unit"
        case .percent: "Discount %"
        case .amount: "Discount per unit"
        }
    }
}

/// Add or edit one line from the quick-grid POS: MRP, quantity and a discount given as a final
/// price, a percent or a rupee amount. An empty discount field means no discount.
@MainActor
@Observable
public final class QuickAddLineViewModel {
    public let original: CartItem
    public let isNew: Bool
    public var mrpText: String
    public var quantity: Int
    public private(set) var mode: QuickDiscountMode
    public var valueText: String

    public init(line: CartItem, isNew: Bool) {
        self.original = line
        self.isNew = isNew
        self.mrpText = line.mrp > 0 ? line.mrp.moneyString : ""
        self.quantity = max(1, line.quantity)
        let hasDiscount = line.discountPercent > 0 && line.mrp > 0
        switch line.discountType {
        case .finalPrice:
            mode = .finalPrice
            valueText = hasDiscount ? line.finalPrice.moneyString : ""
        case .amount:
            mode = .amount
            valueText = hasDiscount ? (line.mrp - line.finalPrice).moneyString : ""
        case .percentage:
            // New lines open on "Final ₹", like the production app.
            mode = hasDiscount || !isNew ? .percent : .finalPrice
            valueText = hasDiscount ? line.discountPercent.moneyString : ""
        }
    }

    public var mrp: Double { max(0, Double(mrpText) ?? 0) }

    /// 0–100; 0 while MRP or the discount field is empty, so it never shows NaN.
    public var discountPercent: Double {
        guard mrp > 0, let value = Double(valueText) else { return 0 }
        let percent: Double
        switch mode {
        case .finalPrice: percent = (mrp - value) / mrp * 100
        case .percent: percent = value
        case .amount: percent = value / mrp * 100
        }
        return min(max(percent, 0), 100)
    }

    private var measure: Double { original.weight ?? Double(quantity) }

    /// Same rounding as `CartItem.finalPrice` / `totalItemsPrice`.
    public var unitPrice: Double { (mrp * (1 - discountPercent / 100)).rounded() }
    public var gross: Double { mrp * measure }
    public var net: Double { (unitPrice * measure).rounded() }
    public var discount: Double { max(0, gross - net) }

    public var isValid: Bool { mrp > 0 && quantity > 0 }

    public func increment() { quantity += 1 }
    public func decrement() { quantity = max(1, quantity - 1) }

    /// Switches mode, re-expressing the current discount in the new mode (to the nearest rupee/percent).
    public func setMode(_ newMode: QuickDiscountMode) {
        guard newMode != mode else { return }
        // Read both before switching: they depend on how `valueText` is interpreted.
        let percent = discountPercent
        let unitPrice = unitPrice
        mode = newMode
        guard percent > 0 else {
            valueText = ""
            return
        }
        switch newMode {
        case .finalPrice: valueText = unitPrice.moneyString
        case .percent: valueText = percent.moneyString
        case .amount: valueText = (mrp - unitPrice).moneyString
        }
    }

    public func build() -> CartItem {
        var line = original
        line.mrp = mrp
        line.quantity = original.weight == nil ? quantity : 1
        line.discountPercent = discountPercent
        switch mode {
        case .finalPrice: line.discountType = .finalPrice
        case .percent: line.discountType = .percentage
        case .amount: line.discountType = .amount
        }
        return line
    }
}
