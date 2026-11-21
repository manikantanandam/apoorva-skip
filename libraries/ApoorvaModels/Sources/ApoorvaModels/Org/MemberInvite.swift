//
//  MemberInvite.swift
//  ApoorvaModels
//

import Foundation

/// An owner's invite for someone to join an organization, at top-level `invites/{orgId}_{email}`
/// (the invitee doesn't know the org yet). Matched to the invitee by verified email and valid until revoked.
public struct MemberInvite: Codable, Sendable, Hashable, Identifiable {
    public enum Status: String, Codable, Sendable {
        case pending, accepted, declined, revoked
    }

    /// Roles an owner can invite someone as.
    public static let invitableRoles: [OrgRole] = [.manager, .cashier]

    public let id: String
    public let orgId: String
    public let orgName: String
    /// Lowercased, trimmed.
    public let email: String
    public var name: String
    public var role: OrgRole
    public var storeIds: [String]
    public let invitedBy: String
    public let invitedByName: String
    public let createdAt: Date
    public var status: Status
    public var acceptedBy: String?
    public var acceptedAt: Date?

    public init(orgId: String, orgName: String, email: String, name: String, role: OrgRole, storeIds: [String],
                invitedBy: String, invitedByName: String, createdAt: Date = Date(), status: Status = .pending,
                acceptedBy: String? = nil, acceptedAt: Date? = nil) {
        let normalized = MemberInvite.normalize(email: email)
        self.id = MemberInvite.makeId(orgId: orgId, email: normalized)
        self.orgId = orgId
        self.orgName = orgName
        self.email = normalized
        self.name = name
        self.role = role
        self.storeIds = storeIds
        self.invitedBy = invitedBy
        self.invitedByName = invitedByName
        self.createdAt = createdAt
        self.status = status
        self.acceptedBy = acceptedBy
        self.acceptedAt = acceptedAt
    }

    public var isPending: Bool { status == .pending }

    public static func normalize(email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// One invite per org and email, so re-inviting the same address updates it instead of duplicating.
    public static func makeId(orgId: String, email: String) -> String {
        "\(orgId)_\(normalize(email: email))"
    }

    public static func isValid(email: String) -> Bool {
        let normalized = normalize(email: email)
        let parts = normalized.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix(".") else { return false }
        // The email is part of the Firestore document id, which can't contain "/" (or whitespace we'd mangle).
        return !normalized.contains("/") && normalized.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }
}
