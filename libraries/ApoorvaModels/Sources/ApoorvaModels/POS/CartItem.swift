//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation


public enum DiscountType: String, Codable, Sendable {
    case percentage
    case amount
    case finalPrice
}

struct CartItem: Codable, Sendable {
    let category: InventoryItem
    let mrp: Double
    let discountPercent: Double
    let quantity: Int
    let discountType: DiscountType
    
    enum CodingKeys: String, CodingKey {
        case category, mrp, discountPercent, quantity, discountType
    }
    
    // Standard Memberwise Initializer
    init(category: InventoryItem,
         mrp: Double,
         discountPercent: Double = 0.0,
         quantity: Int,
         discountType: DiscountType = .percentage) {
        self.category = category
        self.mrp = mrp
        self.discountPercent = discountPercent
        self.quantity = quantity
        self.discountType = discountType
    }
    
    // Handles default values for discountPercent and discountType
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.category = try container.decode(InventoryItem.self, forKey: .category)
        self.mrp = try container.decode(Double.self, forKey: .mrp)
        self.discountPercent = try container.decodeIfPresent(Double.self, forKey: .discountPercent) ?? 0.0
        self.quantity = try container.decode(Int.self, forKey: .quantity)
        self.discountType = try container.decodeIfPresent(DiscountType.self, forKey: .discountType) ?? .percentage
    }
    
    // MARK: - Computed Properties
    var finalPrice: Double {
        return (mrp * (1 - (discountPercent / 100))).rounded()
    }
    
    var totalItemsPrice: Double {
        return (Double(quantity) * finalPrice).rounded()
    }
}
