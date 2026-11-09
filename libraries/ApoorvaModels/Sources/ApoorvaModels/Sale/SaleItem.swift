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
    /// Parlour: who did the service (commission). Optional, additive.
    public var doneByStaffId: String?
    public var doneByName: String?
    public var warrantyMonths: Int?
    /// Loose items: weight sold; `finalPrice` is then the whole line amount and `qty` is 1.
    public var weight: Double?
    public var unit: String?
    public var variant: String?

    enum CodingKeys: String, CodingKey {
        case categoryId = "cat_id"
        case categoryName
        case qty
        case stickerPrice
        case finalPrice
        case discountType
        case doneByStaffId, doneByName, warrantyMonths, weight, unit, variant
    }

    public init(id: String = UUID().uuidString,
                categoryId: String,
                categoryName: String,
                qty: Int,
                stickerPrice: Double,
                finalPrice: Double,
                discountType: DiscountType,
                doneByStaffId: String? = nil,
                doneByName: String? = nil,
                warrantyMonths: Int? = nil,
                weight: Double? = nil,
                unit: String? = nil,
                variant: String? = nil) {
        self.id = id
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.qty = qty
        self.stickerPrice = stickerPrice
        self.finalPrice = finalPrice
        self.discountType = discountType
        self.doneByStaffId = doneByStaffId
        self.doneByName = doneByName
        self.warrantyMonths = warrantyMonths
        self.weight = weight
        self.unit = unit
        self.variant = variant
    }

    /// The sale line for a cart line. Weighed lines become one unit priced at the line amount,
    /// so legacy readers still total them correctly.
    public init(cartItem: CartItem) {
        let isWeighed = cartItem.weight != nil
        self.init(categoryId: cartItem.category.id,
                  categoryName: cartItem.displayName,
                  qty: isWeighed ? 1 : cartItem.quantity,
                  stickerPrice: isWeighed ? cartItem.lineMRP.rounded() : cartItem.mrp,
                  finalPrice: isWeighed ? cartItem.totalItemsPrice : cartItem.finalPrice,
                  discountType: cartItem.discountType,
                  doneByStaffId: cartItem.doneByStaffId,
                  doneByName: cartItem.doneByName,
                  warrantyMonths: cartItem.warrantyMonths,
                  weight: cartItem.weight,
                  unit: cartItem.unit,
                  variant: cartItem.variant)
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
            self.doneByStaffId = try? container.decodeIfPresent(String.self, forKey: .doneByStaffId)
            self.doneByName = try? container.decodeIfPresent(String.self, forKey: .doneByName)
            self.warrantyMonths = try? container.decodeIfPresent(Int.self, forKey: .warrantyMonths)
            self.weight = try? container.decodeIfPresent(Double.self, forKey: .weight)
            self.unit = try? container.decodeIfPresent(String.self, forKey: .unit)
            self.variant = try? container.decodeIfPresent(String.self, forKey: .variant)
        }
    
    // MARK: - Computed Properties
    public var discountPercent: Double {
        if stickerPrice == 0 { return 0.0 }
        return ((stickerPrice - finalPrice) / stickerPrice) * 100
    }
    
    public var unitDiscountAmount: Double {
        return stickerPrice - finalPrice
    }

    public var totalAmount: Double {
        return Double(qty) * finalPrice
    }
}
