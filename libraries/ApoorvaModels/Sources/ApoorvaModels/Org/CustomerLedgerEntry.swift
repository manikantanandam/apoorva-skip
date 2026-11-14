//
//  CustomerLedgerEntry.swift
//  ApoorvaModels
//

import Foundation

public enum LedgerEntryKind: String, Codable, Sendable, CaseIterable {
    /// Credit sale: customer owes more.
    case sale
    /// Customer paid down their due.
    case payment
    /// Due carried over from before the app (onboarding opening balances).
    case opening
    /// Advance taken on an order (reduces what they owe later).
    case advance
    /// Due reversed by a cancelled bill or a return.
    case reversal
    case adjustment
}

/// One line in a customer's dues ledger. `amount` is signed: positive increases what the
/// customer owes, negative reduces it.
public struct CustomerLedgerEntry: OrgDocument {
    public static let collection = "customerLedger"

    public let id: String
    public let customerPhone: String
    public let customerName: String
    public let kind: LedgerEntryKind
    public let amount: Double
    public let mode: String?
    public let saleId: String?
    public let note: String?
    public let createdAt: Date
    public let createdBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(),
                customerPhone: String,
                customerName: String,
                kind: LedgerEntryKind,
                amount: Double,
                mode: String? = nil,
                saleId: String? = nil,
                note: String? = nil,
                createdAt: Date = Date(),
                createdBy: String,
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
        self.id = id
        self.customerPhone = customerPhone
        self.customerName = customerName
        self.kind = kind
        self.amount = amount
        self.mode = mode
        self.saleId = saleId
        self.note = note
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt ?? createdAt
        self.isDeleted = isDeleted
    }
}

public extension Array where Element == CustomerLedgerEntry {
    /// Current due for the entries given (callers filter to one customer).
    var balance: Double {
        filter { !$0.isDeleted }.reduce(0) { $0 + $1.amount }
    }
}
