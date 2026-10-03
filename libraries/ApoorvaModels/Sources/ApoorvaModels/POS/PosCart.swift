//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation

public enum PaymentMode: String, Codable, Sendable {
    case cash
    case upi
    case card
    case credit
}

struct PosCart: Codable, Sendable {
    var items: [CartItem] = []
    var flatDiscount: Double = 0.0
    var paymentMode: PaymentMode = .cash
    var customerPhone: String?
    var customerName: String?
    var socialSource: String?
    var billDateTime: Date = Date()
    
    // MARK: - Computed Properties
    var totalPayable: Double {
        return max(totalFinalPrice - flatDiscount, 0.0)
    }
    
    var totalMRP: Double {
        return items.reduce(0.0) { $0 + ($1.mrp * Double($1.quantity)) }
    }
    
    var totalFinalPrice: Double {
        return items.reduce(0.0) { $0 + ($1.finalPrice * Double($1.quantity)) }
    }
    
    var totalDiscountOnMRP: Double {
        return totalMRP - totalFinalPrice
    }
    
    var totalItemsCount: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
}
