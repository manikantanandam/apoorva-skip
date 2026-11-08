//
//  Permissions.swift
//  ApoorvaModels
//

import Foundation

/// Org-level role (docs/10). Derived from the legacy `AppUserRole` unless an org
/// `members/{uid}` doc sets it explicitly — never written back into `users.role`.
public enum OrgRole: String, Codable, Sendable, CaseIterable, Hashable {
    case owner, manager, cashier, accountant

    public var title: String {
        switch self {
        case .owner: "Owner"
        case .manager: "Manager"
        case .cashier: "Cashier"
        case .accountant: "Accountant"
        }
    }

    public init(appRole: AppUserRole) {
        switch appRole {
        case .admin, .superAdmin: self = .owner
        case .manager: self = .manager
        case .standard: self = .cashier
        }
    }
}

public enum Permission: String, Codable, Sendable, CaseIterable, Hashable {
    case createBill
    case discountAboveLimit
    case cancelBill
    case returns
    case creditSales
    case cashOut
    case dayClose
    case dayReopen
    case editInventory
    case viewInsights
    case undoOwnBill
    case editSavedBill
    case purchases
    case expenses
    case warrantyClaim
    case markAttendance
    case paySalary
    case admin
    case exportReports

    public var title: String {
        switch self {
        case .createBill: "Create bill"
        case .discountAboveLimit: "Discount above limit"
        case .cancelBill: "Cancel bill"
        case .returns: "Returns"
        case .creditSales: "Credit sales"
        case .cashOut: "Cash out"
        case .dayClose: "Day close"
        case .dayReopen: "Reopen day"
        case .editInventory: "Edit inventory"
        case .viewInsights: "View insights"
        case .undoOwnBill: "Undo own bill (5 min)"
        case .editSavedBill: "Edit saved bill"
        case .purchases: "Purchases & supplier payments"
        case .expenses: "Expenses"
        case .warrantyClaim: "Warranty claim"
        case .markAttendance: "Mark attendance"
        case .paySalary: "Pay salary"
        case .admin: "Admin section"
        case .exportReports: "Export reports"
        }
    }
}

/// Which roles hold which permissions. Stored as string keys so it survives Firestore encoding.
public struct PermissionMatrix: Codable, Sendable, Hashable {
    /// role rawValue → permission rawValues
    public var grants: [String: [String]]

    public init(grants: [String: [String]]) {
        self.grants = grants
    }

    public func allows(_ permission: Permission, for role: OrgRole) -> Bool {
        if role == .owner { return true }
        return grants[role.rawValue]?.contains(permission.rawValue) ?? false
    }

    public mutating func set(_ permission: Permission, for role: OrgRole, to isOn: Bool) {
        guard !Self.isLocked(permission, for: role) else { return }
        var list = Set(grants[role.rawValue] ?? [])
        if isOn { list.insert(permission.rawValue) } else { list.remove(permission.rawValue) }
        grants[role.rawValue] = list.sorted()
    }

    /// Owner always has everything; admin is owner-only; cashier must always be able to bill.
    public static func isLocked(_ permission: Permission, for role: OrgRole) -> Bool {
        if role == .owner { return true }
        if permission == .admin { return true }
        if role == .cashier && permission == .createBill { return true }
        return false
    }

    /// docs/10 default matrix.
    public static let standard = PermissionMatrix(grants: [
        OrgRole.manager.rawValue: [
            Permission.createBill, .discountAboveLimit, .cancelBill, .returns, .creditSales, .cashOut,
            .dayClose, .editInventory, .viewInsights, .undoOwnBill, .editSavedBill, .purchases,
            .expenses, .warrantyClaim, .markAttendance, .exportReports
        ].map(\.rawValue),
        OrgRole.cashier.rawValue: [
            Permission.createBill, .returns, .cashOut, .undoOwnBill, .warrantyClaim, .markAttendance
        ].map(\.rawValue),
        OrgRole.accountant.rawValue: [
            Permission.viewInsights, .exportReports
        ].map(\.rawValue)
    ])
}
