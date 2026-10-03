//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation

public struct SaleItem: Codable, Sendable, Identifiable {
    public var id: String
    public let categoryId: String
    public let categoryName: String
    public let qty: Int
    public let stickerPrice: Double
    public let finalPrice: Double
    public let discountType: DiscountType
    
    enum CodingKeys: String, CodingKey {
        case categoryId = "cat_id"
        case categoryName
        case qty
        case stickerPrice
        case finalPrice
        case discountType
    }
    
    public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
            self.categoryId = (try? container.decodeIfPresent(String.self, forKey: .categoryId)) ?? ""
            self.categoryName = (try? container.decodeIfPresent(String.self, forKey: .categoryName)) ?? ""
            self.qty = (try? container.decodeIfPresent(Int.self, forKey: .qty)) ?? 0
            self.stickerPrice = (try? container.decodeIfPresent(Double.self, forKey: .stickerPrice)) ?? 0.0
            self.finalPrice = (try? container.decodeIfPresent(Double.self, forKey: .finalPrice)) ?? 0.0
            self.discountType = (try? container.decodeIfPresent(DiscountType.self, forKey: .discountType)) ?? .finalPrice
        }
    
    // MARK: - Computed Properties
    public var discountPercent: Double {
        if stickerPrice == 0 { return 0.0 }
        return ((stickerPrice - finalPrice) / stickerPrice) * 100
    }
    
    var unitDiscountAmount: Double {
        return stickerPrice - finalPrice
    }
    
    var totalAmount: Double {
        return Double(qty) * finalPrice
    }
}
