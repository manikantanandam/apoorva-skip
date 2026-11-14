//
//  Supplier.swift
//  ApoorvaModels
//

import Foundation

/// Someone the shop buys from. What's owed is `openingDue` plus the supplier ledger.
public struct Supplier: OrgDocument {
    public static let collection = "suppliers"

    public let id: String
    public var name: String
    public var phone: String
    public var openingDue: Double
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), name: String, phone: String = "", openingDue: Double = 0,
                notes: String = "", createdAt: Date = Date(), updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.phone = phone
        self.openingDue = openingDue
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}
