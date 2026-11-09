//
//  LineEditViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaServices

public enum LineDiscountMode: String, CaseIterable, Sendable {
    case none = "None"
    case amount = "₹ off"
    case percent = "% off"
}

/// Edit one bill line (design 33): quantity, price, item discount, warranty.
@MainActor
@Observable
public final class LineEditViewModel {
    public let original: CartItem
    public let isNew: Bool
    public var quantity: Int
    public var priceText: String
    public var discountMode: LineDiscountMode
    public var discountText: String
    public var hasWarranty: Bool
    public var warrantyMonths: Int

    public init(line: CartItem, isNew: Bool) {
        self.original = line
        self.isNew = isNew
        self.quantity = max(1, line.quantity)
        self.priceText = line.mrp > 0 ? line.mrp.moneyString : ""
        let discountAmount = line.mrp - line.finalPrice
        if line.discountPercent <= 0 {
            discountMode = .none
            discountText = ""
        } else if line.discountType == .amount {
            discountMode = .amount
            discountText = discountAmount.moneyString
        } else {
            discountMode = .percent
            discountText = line.discountPercent.moneyString
        }
        self.hasWarranty = (line.warrantyMonths ?? 0) > 0
        self.warrantyMonths = line.warrantyMonths ?? line.category.warrantyMonths ?? 6
    }

    public var price: Double { Double(priceText) ?? 0 }

    public var discountPercent: Double {
        let value = Double(discountText) ?? 0
        switch discountMode {
        case .none: return 0
        case .percent: return min(max(value, 0), 100)
        case .amount: return price > 0 ? min(max(value / price * 100, 0), 100) : 0
        }
    }

    public var lineTotal: Double {
        let unit = (price * (1 - discountPercent / 100)).rounded()
        return unit * (original.weight ?? Double(quantity))
    }

    public var warrantyEnds: Date {
        Calendar.current.date(byAdding: .month, value: warrantyMonths, to: Date()) ?? Date()
    }

    public var isValid: Bool { price > 0 && quantity > 0 }

    public func increment() { quantity += 1 }
    public func decrement() { quantity = max(1, quantity - 1) }

    public func build() -> CartItem {
        var line = original
        line.mrp = price
        line.quantity = original.weight == nil ? quantity : 1
        line.discountPercent = discountPercent
        line.discountType = discountMode == .amount ? .amount : .percentage
        line.warrantyMonths = hasWarranty ? warrantyMonths : nil
        return line
    }
}

/// Bill discount (design 34). Above the role's limit a manager approves with their PIN on this phone.
@MainActor
@Observable
public final class BillDiscountViewModel {
    public enum Mode: String, CaseIterable, Sendable { case amount = "₹ amount", percent = "%" }

    public let subtotal: Double
    public let limitPercent: Double
    public var mode: Mode
    public var valueText: String
    public var managerPin = ""
    public private(set) var isApprovedByManager = false
    public var errorMessage: String?

    private let managers: [Member]
    private let pinStore: PinStoring

    public init(subtotal: Double, currentAmount: Double, currentPercent: Double?, limitPercent: Double,
                managers: [Member], pinStore: PinStoring) {
        self.subtotal = subtotal
        self.limitPercent = limitPercent
        self.managers = managers
        self.pinStore = pinStore
        if let currentPercent {
            mode = .percent
            valueText = currentPercent.moneyString
        } else {
            mode = currentAmount > 0 ? .amount : .percent
            valueText = currentAmount > 0 ? currentAmount.moneyString : ""
        }
    }

    public var amount: Double {
        let value = Double(valueText) ?? 0
        return min(subtotal, mode == .percent ? (subtotal * value / 100).rounded() : value)
    }

    public var percent: Double { subtotal > 0 ? amount / subtotal * 100 : 0 }
    public var newTotal: Double { subtotal - amount }
    /// Checks the percent as typed in % mode, so rounding the rupee amount up can't trip the limit.
    public var needsApproval: Bool {
        let checked = mode == .percent ? (Double(valueText) ?? 0) : percent
        return checked > limitPercent + 0.001 && !isApprovedByManager
    }
    public var canApply: Bool { !needsApproval }

    /// "Round to ₹1,050": the discount that brings the total down to the nearest ₹50.
    public var roundDownTarget: Double { (subtotal / 50).rounded(.down) * 50 }

    public func roundTotal() {
        mode = .amount
        valueText = (subtotal - roundDownTarget).moneyString
    }

    public func preset(_ percent: Double) {
        mode = .percent
        valueText = percent.moneyString
    }

    /// Returns true once a manager's PIN matches.
    public func managerKey(_ key: ManiKeypadKeyLike) -> Bool {
        managerPin = key.apply(managerPin)
        guard managerPin.count == 4 else { return false }
        if managers.contains(where: { pinStore.verify(managerPin, for: $0.id) }) {
            isApprovedByManager = true
            errorMessage = nil
            return true
        }
        errorMessage = "That PIN isn't a manager's. Try again."
        managerPin = ""
        return false
    }

    public var appliedPercent: Double? { mode == .percent ? Double(valueText) : nil }
}

/// Keeps keypad handling in view models free of the UI library type.
public enum ManiKeypadKeyLike: Sendable {
    case digit(Int), backspace

    func apply(_ text: String) -> String {
        switch self {
        case .digit(let value): text.count < 4 ? text + "\(value)" : text
        case .backspace: String(text.dropLast())
        }
    }
}
