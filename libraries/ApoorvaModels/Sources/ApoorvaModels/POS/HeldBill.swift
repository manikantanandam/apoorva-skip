//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation

public struct HeldBill: Codable, Sendable, Identifiable {
    public let id: String
    public let customerName: String
    public let customerPhone: String
    public let items: [CartItem]
    public let total: Double
    public let createdAt: Date
    public var updatedAt: Date?
    public var isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, customerName, customerPhone, items, total, createdAt, updatedAt, isDeleted
    }

    public init(id: String = DocumentID.make(),
                customerName: String,
                customerPhone: String,
                items: [CartItem],
                total: Double,
                createdAt: Date = Date(),
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
        self.id = id
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.items = items
        self.total = total
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? DocumentID.make()
        self.customerName = (try? container.decodeIfPresent(String.self, forKey: .customerName)) ?? ""
        self.customerPhone = (try? container.decodeIfPresent(String.self, forKey: .customerPhone)) ?? ""
        self.items = (try? container.decodeIfPresent([CartItem].self, forKey: .items)) ?? []
        self.total = (try? container.decodeIfPresent(Double.self, forKey: .total)) ?? 0.0
        self.createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        self.updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
        self.isDeleted = (try? container.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false
    }
}

extension HeldBill: Comparable {
    public static func == (lhs: HeldBill, rhs: HeldBill) -> Bool {
        return lhs.id == rhs.id
    }

    public static func < (lhs: HeldBill, rhs: HeldBill) -> Bool {
        return lhs.createdAt < rhs.createdAt
    }
}
