//
//  Store.swift
//  ApoorvaModels
//

import Foundation

/// A shop within an org. Legacy single-shop orgs have no store docs; the app uses
/// `Store.defaultStore(...)` for them until an admin saves one.
public struct Store: OrgDocument {
    public static let collection = "stores"
    public static let defaultId = "default"

    public let id: String
    public var name: String
    public var vertical: Vertical
    public var address: String
    public var phone: String
    public var billPrefix: String
    public var accent: AccentKey?
    public var isLive: Bool
    public var createdAt: Date
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = UUID().uuidString,
                name: String,
                vertical: Vertical,
                address: String = "",
                phone: String = "",
                billPrefix: String = "",
                accent: AccentKey? = nil,
                isLive: Bool = true,
                createdAt: Date = Date(),
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.vertical = vertical
        self.address = address
        self.phone = phone
        self.billPrefix = billPrefix
        self.accent = accent
        self.isLive = isLive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public static func defaultStore(name: String, vertical: Vertical, billPrefix: String = "A-") -> Store {
        Store(id: defaultId, name: name, vertical: vertical, billPrefix: billPrefix)
    }
}

/// Per-org membership: role and store access. Keyed by the member's uid.
public struct Member: OrgDocument {
    public static let collection = "members"

    public let id: String
    public var name: String
    public var phone: String
    public var email: String
    public var role: OrgRole
    public var storeIds: [String]
    public var isActive: Bool
    /// "invited" until the person joins with the invite link.
    public var status: String
    public var commissionPercent: Double?
    public var baseSalary: Double?
    public var joinedAt: Date?
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String,
                name: String,
                phone: String = "",
                email: String = "",
                role: OrgRole,
                storeIds: [String] = [Store.defaultId],
                isActive: Bool = true,
                status: String = "active",
                commissionPercent: Double? = nil,
                baseSalary: Double? = nil,
                joinedAt: Date? = Date(),
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.role = role
        self.storeIds = storeIds
        self.isActive = isActive
        self.status = status
        self.commissionPercent = commissionPercent
        self.baseSalary = baseSalary
        self.joinedAt = joinedAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}
