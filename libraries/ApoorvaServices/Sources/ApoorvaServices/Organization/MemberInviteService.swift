//
//  MemberInviteService.swift
//  ApoorvaServices
//

import Foundation
import SkipFirebaseFirestore
import ApoorvaModels

public protocol MemberInviteServicing: Sendable {
    /// Writes (or re-sends) the invite at `invites/{id}`.
    func send(_ invite: MemberInvite) throws
    func pendingInvites(orgId: String) async throws -> [MemberInvite]
    func revoke(_ invite: MemberInvite) async throws
    /// Invites addressed to this email (the invitee's side). Callers pass a verified email only.
    func pendingInvites(forEmail email: String) async throws -> [MemberInvite]
    /// Joins the invite's org: the user's profile gets the org and its `orgMembership` entry, invite marked accepted.
    /// `makeCurrent` also selects the org (the invitee had none); `createProfile` writes a full `users/{uid}`
    /// doc, only for accounts that have no profile yet.
    func accept(_ invite: MemberInvite, account: AuthAccount, name: String,
                existingOrgs: [OrganizationSnapshot], makeCurrent: Bool, createProfile: Bool) async throws
    func decline(_ invite: MemberInvite) async throws
}

public final class MemberInviteService: MemberInviteServicing, @unchecked Sendable {
    private static let collection = "invites"
    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func send(_ invite: MemberInvite) throws {
        try store.setData(try Firestore.Encoder().encode(invite), path: "\(Self.collection)/\(invite.id)", merge: false)
    }

    public func pendingInvites(orgId: String) async throws -> [MemberInvite] {
        try await pending(field: "orgId", value: orgId)
    }

    public func pendingInvites(forEmail email: String) async throws -> [MemberInvite] {
        try await pending(field: "email", value: MemberInvite.normalize(email: email))
    }

    public func accept(_ invite: MemberInvite, account: AuthAccount, name: String,
                       existingOrgs: [OrganizationSnapshot], makeCurrent: Bool, createProfile: Bool) async throws {
        let now = Date()
        let snapshot = OrganizationSnapshot(orgId: invite.orgId, name: invite.orgName)
        let orgs = existingOrgs.filter { $0.orgId != invite.orgId } + [snapshot]
        // An existing (possibly legacy) profile only gets the additive org fields; its name, role, createdAt
        // and the rest are never rewritten (docs/12 §9). The role for this org lives in `orgMembership`.
        let membership = OrgMembership(role: invite.role, storeIds: invite.storeIds, isActive: true, joinedAt: now)
        var profile: [String: Any] = [
            "assignedOrgs": try orgs.map { try Firestore.Encoder().encode($0) },
            "assignedOrgIds": orgs.map(\.orgId),
            "orgMembership": [invite.orgId: try Firestore.Encoder().encode(membership)],
            "updatedAt": now,
            "updatedTimestamp": now.timeIntervalSince1970
        ]
        if makeCurrent { profile["selectedOrganization"] = try Firestore.Encoder().encode(snapshot) }
        if createProfile {
            let legacyRole: AppUserRole = invite.role == .manager ? .manager : .standard
            profile["id"] = account.uid
            profile["name"] = name
            profile["email"] = account.email ?? invite.email
            profile["role"] = legacyRole.rawValue
            profile["status"] = "active"
            profile["createdAt"] = now
            profile["url"] = ""
            profile["isDeleted"] = false
        }
        try store.setData(profile, path: "\(String.users)/\(account.uid)", merge: true)

        try await store.updateData(["status": MemberInvite.Status.accepted.rawValue,
                                    "acceptedBy": account.uid, "acceptedAt": now],
                                   path: "\(Self.collection)/\(invite.id)")
    }

    public func decline(_ invite: MemberInvite) async throws {
        try await store.updateData(["status": MemberInvite.Status.declined.rawValue], path: "\(Self.collection)/\(invite.id)")
    }

    private func pending(field: String, value: String) async throws -> [MemberInvite] {
        let documents = try await store.getDocuments(
            collection: Self.collection,
            query: StoreQuery(conditions: [.isIn(field: field, values: [value])]))
        // Skip documents that aren't member invites (e.g. old code-based invites) instead of failing the list.
        return documents
            .compactMap { try? Firestore.Decoder().decode(MemberInvite.self, from: $0.data) }
            .filter(\.isPending)
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func revoke(_ invite: MemberInvite) async throws {
        try await store.updateData(["status": MemberInvite.Status.revoked.rawValue], path: "\(Self.collection)/\(invite.id)")
    }
}
