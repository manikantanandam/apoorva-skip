//
//  Invite.swift
//  ApoorvaModels
//

import Foundation

/// A staff invite at top-level `invites/{token}` (the joiner doesn't know the org yet).
/// Valid for 72 hours; expiry is checked on the client until rules/Functions enforce it.
public struct Invite: Codable, Sendable, Hashable, Identifiable {
    public var id: String { token }
    public let token: String
    public let orgId: String
    public let orgName: String
    public let storeIds: [String]
    public let storeName: String
    public let role: OrgRole
    public let name: String
    public let phone: String
    public let invitedBy: String
    public let invitedByName: String
    public let createdAt: Date
    public let expiresAt: Date
    public var acceptedBy: String?
    public var acceptedAt: Date?

    public init(token: String = Invite.makeToken(), orgId: String, orgName: String, storeIds: [String], storeName: String,
                role: OrgRole, name: String, phone: String, invitedBy: String, invitedByName: String,
                createdAt: Date = Date(), expiresAt: Date? = nil, acceptedBy: String? = nil, acceptedAt: Date? = nil) {
        self.token = token
        self.orgId = orgId
        self.orgName = orgName
        self.storeIds = storeIds
        self.storeName = storeName
        self.role = role
        self.name = name
        self.phone = phone
        self.invitedBy = invitedBy
        self.invitedByName = invitedByName
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(72 * 3600)
        self.acceptedBy = acceptedBy
        self.acceptedAt = acceptedAt
    }

    public var isExpired: Bool { Date() > expiresAt }
    public var isAccepted: Bool { acceptedBy != nil }

    /// Short, human-typeable code (no ambiguous 0/O/1/I).
    public static func makeToken() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }

    /// Link sent by SMS/WhatsApp; the app handles `apoorva://join/<token>`.
    public var link: String { "apoorva://join/\(token)" }
}
