//
//  OrgMembership.swift
//  ApoorvaModels
//

import Foundation

/// Per-org settings for a user, stored additively on `users/{uid}.orgMembership.{orgId}`.
/// Every field is optional: a legacy user without an entry keeps the role derived from `users.role`.
public struct OrgMembership: Codable, Sendable, Hashable {
    public var role: OrgRole?
    /// Empty or missing means access to every store.
    public var storeIds: [String]?
    public var phone: String?
    public var isActive: Bool?
    public var baseSalary: Double?
    public var commissionPercent: Double?
    public var joinedAt: Date?

    public init(role: OrgRole? = nil, storeIds: [String]? = nil, phone: String? = nil, isActive: Bool? = nil,
                baseSalary: Double? = nil, commissionPercent: Double? = nil, joinedAt: Date? = nil) {
        self.role = role
        self.storeIds = storeIds
        self.phone = phone
        self.isActive = isActive
        self.baseSalary = baseSalary
        self.commissionPercent = commissionPercent
        self.joinedAt = joinedAt
    }
}

public extension AppUser {
    /// This user as a member of `orgId`, built from the profile doc plus its optional per-org entry.
    func member(in orgId: String) -> Member {
        let entry = orgMembership[orgId]
        let active = entry?.isActive ?? !isDeleted
        return Member(id: id,
                      name: name,
                      phone: entry?.phone ?? "",
                      email: email,
                      role: entry?.role ?? OrgRole(appRole: role),
                      storeIds: entry?.storeIds ?? [],
                      isActive: active,
                      status: active ? "active" : "inactive",
                      commissionPercent: entry?.commissionPercent,
                      baseSalary: entry?.baseSalary,
                      joinedAt: entry?.joinedAt ?? createdAt,
                      updatedAt: updatedAt,
                      isDeleted: isDeleted)
    }
}
