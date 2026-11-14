//
//  StockMovement.swift
//  ApoorvaModels
//

import Foundation

public enum StockMovementReason: String, Codable, Sendable, CaseIterable {
    case sale, purchase, purchaseReturn, customerReturn, cancel, adjustment, damage, opening
}

/// A signed change to an item's stock. The item's `currentStock` is the running total;
/// movements are the history behind it.
public struct StockMovement: OrgDocument {
    public static let collection = "stockMovements"

    public let id: String
    public let itemId: String
    public let itemName: String
    public let delta: Double
    public let reason: StockMovementReason
    public let refId: String?
    public let note: String?
    public let createdAt: Date
    public let createdBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(),
                itemId: String,
                itemName: String,
                delta: Double,
                reason: StockMovementReason,
                refId: String? = nil,
                note: String? = nil,
                createdAt: Date = Date(),
                createdBy: String,
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
        self.id = id
        self.itemId = itemId
        self.itemName = itemName
        self.delta = delta
        self.reason = reason
        self.refId = refId
        self.note = note
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt ?? createdAt
        self.isDeleted = isDeleted
    }
}
