//
//  CartItem.swift
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

/// One line on the bill being built. Prices are per unit (or per kg/litre when `weight` is set).
public struct CartItem: Codable, Sendable, Identifiable {
    public var category: InventoryItem
    public var mrp: Double
    public var discountPercent: Double
    public var quantity: Int
    public var discountType: DiscountType
    /// Loose items sold by weight/volume (kirana): the line is `weight × price`, quantity stays 1.
    public var weight: Double?
    /// "kg", "g", "l"… shown next to the weight.
    public var unit: String?
    /// Size/colour picked in the variant sheet, e.g. "2.4 · Ruby".
    public var variant: String?
    /// Parlour: who did the service, for commission.
    public var doneByStaffId: String?
    public var doneByName: String?
    public var warrantyMonths: Int?
    /// Stable per-line id, so the same item can be on the bill twice (different variants).
    public var lineId: String

    public var id: String { lineId }

    enum CodingKeys: String, CodingKey {
        case category, mrp, discountPercent, quantity, discountType
        case weight, unit, variant, doneByStaffId, doneByName, warrantyMonths, lineId
    }

    public init(category: InventoryItem,
                mrp: Double,
                discountPercent: Double = 0.0,
                quantity: Int,
                discountType: DiscountType = .percentage,
                weight: Double? = nil,
                unit: String? = nil,
                variant: String? = nil,
                doneByStaffId: String? = nil,
                doneByName: String? = nil,
                warrantyMonths: Int? = nil,
                lineId: String? = nil) {
        self.category = category
        self.mrp = mrp
        self.discountPercent = discountPercent
        self.quantity = quantity
        self.discountType = discountType
        self.weight = weight
        self.unit = unit
        self.variant = variant
        self.doneByStaffId = doneByStaffId
        self.doneByName = doneByName
        self.warrantyMonths = warrantyMonths
        self.lineId = lineId ?? (variant.map { "\(category.id)#\($0)" } ?? category.id)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.category = try container.decode(InventoryItem.self, forKey: .category)
        self.mrp = try container.decode(Double.self, forKey: .mrp)
        self.discountPercent = try container.decodeIfPresent(Double.self, forKey: .discountPercent) ?? 0.0
        self.quantity = try container.decode(Int.self, forKey: .quantity)
        self.discountType = try container.decodeIfPresent(DiscountType.self, forKey: .discountType) ?? .percentage
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit)
        self.variant = try container.decodeIfPresent(String.self, forKey: .variant)
        self.doneByStaffId = try container.decodeIfPresent(String.self, forKey: .doneByStaffId)
        self.doneByName = try container.decodeIfPresent(String.self, forKey: .doneByName)
        self.warrantyMonths = try container.decodeIfPresent(Int.self, forKey: .warrantyMonths)
        self.lineId = try container.decodeIfPresent(String.self, forKey: .lineId) ?? category.id
    }

    // MARK: - Computed Properties

    /// Price per unit after the line discount.
    public var finalPrice: Double {
        return (mrp * (1 - (discountPercent / 100))).rounded()
    }

    /// How many units the line is for: the weight for loose items, otherwise the quantity.
    public var measure: Double {
        weight ?? Double(quantity)
    }

    public var totalItemsPrice: Double {
        return (measure * finalPrice).rounded()
    }

    public var lineMRP: Double {
        mrp * measure
    }

    /// "Toor Dal · 0.5 kg", "Glass Bangles · 2.4 · Ruby".
    public var displayName: String {
        var parts = [category.name]
        if let variant { parts.append(variant) }
        if let weight { parts.append("\(Self.format(weight)) \(unit ?? "kg")") }
        return parts.joined(separator: " · ")
    }

    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.3g", value)
    }
}
