//
//  Packages.swift
//  ApoorvaModels
//

import Foundation

/// A package or membership a parlour sells, e.g. "Glow Facial × 5" (design 39).
public struct ServicePackage: OrgDocument {
    public static let collection = "servicePackages"

    public let id: String
    public var name: String
    public var details: String
    public var price: Double
    /// Number of sessions included; 0 means a membership with no session count.
    public var sessions: Int
    public var validityDays: Int
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = UUID().uuidString, name: String, details: String = "", price: Double, sessions: Int,
                validityDays: Int = 90, updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.details = details
        self.price = price
        self.sessions = sessions
        self.validityDays = validityDays
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

/// A package a customer bought, and how many sessions they've used.
public struct CustomerPackage: OrgDocument {
    public static let collection = "customerPackages"

    public let id: String
    public let packageId: String
    public let name: String
    public let customerPhone: String
    public let customerName: String
    public let price: Double
    public let sessions: Int
    public var sessionsUsed: Int
    public let purchasedAt: Date
    public let validUntil: Date
    public let saleId: String?
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = UUID().uuidString, package: ServicePackage, customerPhone: String, customerName: String,
                purchasedAt: Date = Date(), saleId: String? = nil, sessionsUsed: Int = 0,
                updatedAt: Date? = nil, isDeleted: Bool = false) {
        self.id = id
        self.packageId = package.id
        self.name = package.name
        self.customerPhone = customerPhone
        self.customerName = customerName
        self.price = package.price
        self.sessions = package.sessions
        self.sessionsUsed = sessionsUsed
        self.purchasedAt = purchasedAt
        self.validUntil = Calendar.current.date(byAdding: .day, value: package.validityDays, to: purchasedAt) ?? purchasedAt
        self.saleId = saleId
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public var sessionsLeft: Int { max(0, sessions - sessionsUsed) }
    public var isExpired: Bool { Date() > validUntil }
    public var isActive: Bool { !isExpired && (sessions == 0 || sessionsLeft > 0) }
}
