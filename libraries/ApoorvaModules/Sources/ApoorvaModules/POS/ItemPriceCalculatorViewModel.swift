//
//  ItemPriceCalculatorViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels

@MainActor
@Observable
public class ItemPriceCalculatorViewModel {

    public let category: InventoryItem
    public let isEditMode: Bool

    public var mrpText: String
    public var quantity: Int
    public var discountType: DiscountType
    /// Meaning depends on `discountType`: the % value, the ₹ discount amount, or the
    /// desired final per-unit price — whichever the segmented control currently shows.
    public var dynamicInputText: String

    public init(category: InventoryItem, existingItem: CartItem? = nil) {
        self.category = category
        self.isEditMode = existingItem != nil

        let mrp = existingItem?.mrp ?? 0
        let discountPercent = existingItem?.discountPercent ?? 0
        let type = existingItem?.discountType ?? .percentage

        self.mrpText = mrp > 0 ? mrp.moneyString : ""
        self.quantity = existingItem?.quantity ?? 1
        self.discountType = type
        self.dynamicInputText = Self.dynamicInputText(for: type, mrp: mrp, discountPercent: discountPercent)
    }

    public var mrp: Double {
        Double(mrpText) ?? 0
    }

    /// Whatever mode the user is entering the discount in, this is always converted
    /// to a percent — `CartItem` only stores `discountPercent`.
    public var discountPercent: Double {
        let input = Double(dynamicInputText) ?? 0
        switch discountType {
        case .percentage:
            return input
        case .amount:
            guard mrp > 0 else { return 0 }
            return (input / mrp) * 100
        case .finalPrice:
            guard mrp > 0 else { return 0 }
            return ((mrp - input) / mrp) * 100
        }
    }

    public var unitFinalPrice: Double {
        (mrp * (1 - (discountPercent / 100))).rounded()
    }

    public var grossTotal: Double {
        mrp * Double(quantity)
    }

    public var netPayable: Double {
        unitFinalPrice * Double(quantity)
    }

    public var discountAmount: Double {
        grossTotal - netPayable
    }

    public var isValid: Bool {
        mrp > 0 && quantity > 0 && discountPercent >= 0 && discountPercent <= 100
    }

    public func applyQuickPercent(_ percent: Double) {
        discountType = .percentage
        dynamicInputText = percent.moneyString
    }

    public func increment() {
        quantity += 1
    }

    public func decrement() {
        guard quantity > 1 else { return }
        quantity -= 1
    }

    public func buildCartItem() -> CartItem {
        CartItem(
            category: category,
            mrp: mrp,
            discountPercent: discountPercent,
            quantity: quantity,
            discountType: discountType
        )
    }

    private static func dynamicInputText(for type: DiscountType, mrp: Double, discountPercent: Double) -> String {
        guard mrp > 0 else { return "" }
        switch type {
        case .percentage:
            return discountPercent > 0 ? discountPercent.moneyString : ""
        case .amount:
            let amount = mrp * discountPercent / 100
            return amount > 0 ? amount.moneyString : ""
        case .finalPrice:
            let finalPrice = mrp * (1 - discountPercent / 100)
            return finalPrice.moneyString
        }
    }
}
