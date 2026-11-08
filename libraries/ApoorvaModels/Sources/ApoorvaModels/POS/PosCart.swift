//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation

public enum PaymentMode: String, Codable, Sendable, CaseIterable {
    case cash
    case upi
    case card
    case credit
}

public struct PosCart: Codable, Sendable {
    public var items: [CartItem] = []
    public var flatDiscount: Double = 0.0
    public var paymentMode: PaymentMode = .cash
    public var customerPhone: String?
    public var customerName: String?
    public var socialSource: String?
    public var billDateTime: Date = Date()

    public init(items: [CartItem] = [],
                flatDiscount: Double = 0.0,
                paymentMode: PaymentMode = .cash,
                customerPhone: String? = nil,
                customerName: String? = nil,
                socialSource: String? = nil,
                billDateTime: Date = Date()) {
        self.items = items
        self.flatDiscount = flatDiscount
        self.paymentMode = paymentMode
        self.customerPhone = customerPhone
        self.customerName = customerName
        self.socialSource = socialSource
        self.billDateTime = billDateTime
    }

    // MARK: - Computed Properties
    public var totalPayable: Double {
        return max(totalFinalPrice - flatDiscount, 0.0)
    }

    public var totalMRP: Double {
        return items.reduce(0.0) { $0 + ($1.mrp * Double($1.quantity)) }
    }

    public var totalFinalPrice: Double {
        return items.reduce(0.0) { $0 + ($1.finalPrice * Double($1.quantity)) }
    }

    public var totalDiscountOnMRP: Double {
        return totalMRP - totalFinalPrice
    }

    public var totalItemsCount: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
}
