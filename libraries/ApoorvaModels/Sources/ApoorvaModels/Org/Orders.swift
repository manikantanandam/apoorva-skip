//
//  Orders.swift
//  ApoorvaModels
//

import Foundation

public enum OrderStatus: String, Codable, Sendable, CaseIterable {
    case open, ready, delivered, cancelled

    public var title: String { rawValue.capitalized }
}

public enum OrderFulfilment: String, Codable, Sendable, CaseIterable {
    case pickup, delivery

    public var title: String { rawValue.capitalized }
}

/// Custom work, repairs or home delivery with an advance (designs 58–60).
/// The advance is booked as cash in when taken; delivering bills only the balance.
public struct Order: OrgDocument {
    public static let collection = "orders"

    public let id: String
    public var number: String
    public var customerPhone: String
    public var customerName: String
    public var details: String
    public var total: Double
    public var advance: Double
    public var advanceMode: String
    public var readyBy: Date
    public var fulfilment: OrderFulfilment
    public var notifyWhenReady: Bool
    public var status: OrderStatus
    public var readyAt: Date?
    public var deliveredAt: Date?
    public var saleId: String?
    public var createdAt: Date
    public var createdBy: String
    public var createdByName: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), number: String, customerPhone: String, customerName: String,
                details: String, total: Double, advance: Double, advanceMode: String = PaymentMode.cash.rawValue,
                readyBy: Date, fulfilment: OrderFulfilment = .pickup, notifyWhenReady: Bool = true,
                status: OrderStatus = .open, readyAt: Date? = nil, deliveredAt: Date? = nil, saleId: String? = nil,
                createdAt: Date = Date(), createdBy: String, createdByName: String = "",
                updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.number = number
        self.customerPhone = customerPhone
        self.customerName = customerName
        self.details = details
        self.total = total
        self.advance = advance
        self.advanceMode = advanceMode
        self.readyBy = readyBy
        self.fulfilment = fulfilment
        self.notifyWhenReady = notifyWhenReady
        self.status = status
        self.readyAt = readyAt
        self.deliveredAt = deliveredAt
        self.saleId = saleId
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public var balance: Double { max(0, total - advance) }
    public var isOverdue: Bool { status == .open && readyBy < Calendar.current.startOfDay(for: Date()) }
}

public enum WarrantyAction: String, Codable, Sendable, CaseIterable {
    case replace, repair, refund

    public var title: String { rawValue.capitalized }
}

/// A warranty claim against a sold item (design 63).
public struct WarrantyClaim: OrgDocument {
    public static let collection = "warrantyClaims"

    public let id: String
    public let saleId: String
    public let billNumber: String
    public let itemId: String
    public let itemName: String
    public let customerPhone: String
    public let action: WarrantyAction
    public let note: String
    public let createdAt: Date
    public let createdBy: String
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = DocumentID.make(), saleId: String, billNumber: String, itemId: String, itemName: String,
                customerPhone: String, action: WarrantyAction, note: String, createdAt: Date = Date(), createdBy: String,
                updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.saleId = saleId
        self.billNumber = billNumber
        self.itemId = itemId
        self.itemName = itemName
        self.customerPhone = customerPhone
        self.action = action
        self.note = note
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

/// A customer's statement for a period, built from their ledger (design 68).
public struct CustomerStatement: Equatable, Sendable {
    public let opening: Double
    public let bills: Double
    public let payments: Double
    public let entries: [CustomerLedgerEntry]

    public var closing: Double { opening + bills - payments }

    /// Positive entries (bills, openings, advances owed) add; negative ones (payments, reversals) subtract.
    public init(entries all: [CustomerLedgerEntry], from start: Date, to end: Date) {
        let sorted = all.filter { !$0.isDeleted }.sorted { $0.createdAt < $1.createdAt }
        opening = sorted.filter { $0.createdAt < start }.reduce(0) { $0 + $1.amount }
        let inPeriod = sorted.filter { $0.createdAt >= start && $0.createdAt <= end }
        bills = inPeriod.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        payments = inPeriod.filter { $0.amount < 0 }.reduce(0) { $0 - $1.amount }
        entries = inPeriod
    }

    public static func == (lhs: CustomerStatement, rhs: CustomerStatement) -> Bool {
        lhs.opening == rhs.opening && lhs.bills == rhs.bills && lhs.payments == rhs.payments
            && lhs.entries.map(\.id) == rhs.entries.map(\.id)
    }
}
