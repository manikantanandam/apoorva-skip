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
    /// "retail" or "wholesale" (design 41).
    public var priceTier: String?
    /// Bill-level discount as entered (for showing "10%" back), alongside the rupee `flatDiscount`.
    public var discountPercent: Double?
    /// Set when this cart is a return of a past bill.
    public var returnOfSaleId: String?

    enum CodingKeys: String, CodingKey {
        case items, flatDiscount, paymentMode, customerPhone, customerName, socialSource, billDateTime
        case priceTier, discountPercent, returnOfSaleId
    }

    public init(items: [CartItem] = [],
                flatDiscount: Double = 0.0,
                paymentMode: PaymentMode = .cash,
                customerPhone: String? = nil,
                customerName: String? = nil,
                socialSource: String? = nil,
                billDateTime: Date = Date(),
                priceTier: String? = nil,
                discountPercent: Double? = nil,
                returnOfSaleId: String? = nil) {
        self.items = items
        self.flatDiscount = flatDiscount
        self.paymentMode = paymentMode
        self.customerPhone = customerPhone
        self.customerName = customerName
        self.socialSource = socialSource
        self.billDateTime = billDateTime
        self.priceTier = priceTier
        self.discountPercent = discountPercent
        self.returnOfSaleId = returnOfSaleId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode([CartItem].self, forKey: .items)) ?? []
        flatDiscount = (try? c.decode(Double.self, forKey: .flatDiscount)) ?? 0
        paymentMode = (try? c.decode(PaymentMode.self, forKey: .paymentMode)) ?? .cash
        customerPhone = try? c.decode(String.self, forKey: .customerPhone)
        customerName = try? c.decode(String.self, forKey: .customerName)
        socialSource = try? c.decode(String.self, forKey: .socialSource)
        billDateTime = (try? c.decode(Date.self, forKey: .billDateTime)) ?? Date()
        priceTier = try? c.decode(String.self, forKey: .priceTier)
        discountPercent = try? c.decode(Double.self, forKey: .discountPercent)
        returnOfSaleId = try? c.decode(String.self, forKey: .returnOfSaleId)
    }

    // MARK: - Computed Properties
    public var totalPayable: Double {
        return max(totalFinalPrice - flatDiscount, 0.0)
    }

    public var totalMRP: Double {
        return items.reduce(0.0) { $0 + $1.lineMRP }
    }

    public var totalFinalPrice: Double {
        return items.reduce(0.0) { $0 + $1.totalItemsPrice }
    }

    public var totalDiscountOnMRP: Double {
        return totalMRP - totalFinalPrice
    }

    public var totalItemsCount: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
}
