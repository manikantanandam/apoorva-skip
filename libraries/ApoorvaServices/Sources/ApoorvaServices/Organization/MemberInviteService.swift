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
    /// Re-reads the stored invite first and throws `MemberInviteError.notPending` if it was revoked, declined or
    /// already used (or addressed to another email). `makeCurrent` also selects the org (the invitee had none).
    /// A full `users/{uid}` doc is written only when none exists in Firestore.
    func accept(_ invite: MemberInvite, account: AuthAccount, name: String,
                existingOrgs: [OrganizationSnapshot], makeCurrent: Bool) async throws
    func decline(_ invite: MemberInvite) async throws
    /// Keeps the per-org role in step when an owner edits a member's role (see `AppUser.member(in:)`).
    func updateMembershipRole(userId: String, orgId: String, role: OrgRole) async throws
}

public enum MemberInviteError: Error {
    /// The invite is no longer pending, or isn't addressed to the signed-in account.
    case notPending
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
                       existingOrgs: [OrganizationSnapshot], makeCurrent: Bool) async throws {
        // Trust the stored invite, not the caller's copy: it may have been revoked since the list was loaded.
        guard let document = try await store.getDocument(path: "\(Self.collection)/\(invite.id)"),
              let stored = try? Firestore.Decoder().decode(MemberInvite.self, from: document.data),
              stored.isPending,
              stored.email == MemberInvite.normalize(email: account.email ?? "") else {
            throw MemberInviteError.notPending
        }
        let invite = stored
        let createProfile = try await store.getDocument(path: "\(String.users)/\(account.uid)") == nil

        let now = Date()
        let snapshot = OrganizationSnapshot(orgId: invite.orgId, name: invite.orgName)
        // An existing (possibly legacy) profile only gets the additive org fields; its name, role, createdAt
        // and the rest are never rewritten (docs/12 §9). The role for this org lives in `orgMembership`.
        // Org lists are unioned, not rewritten, so another device's newer assignments aren't dropped.
        let membership = OrgMembership(role: invite.role, storeIds: invite.storeIds, isActive: true, joinedAt: now)
        var profile: [String: Any] = [
            "assignedOrgIds": StoreArrayUnion([invite.orgId]),
            "orgMembership": [invite.orgId: try Firestore.Encoder().encode(membership)],
            "updatedAt": now,
            "updatedTimestamp": now.timeIntervalSince1970
        ]
        if !existingOrgs.contains(where: { $0.orgId == invite.orgId }) {
            profile["assignedOrgs"] = StoreArrayUnion([try Firestore.Encoder().encode(snapshot)])
        }
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

    public func updateMembershipRole(userId: String, orgId: String, role: OrgRole) async throws {
        try await store.updateData(["orgMembership.\(orgId).role": role.rawValue,
                                    "updatedTimestamp": Date().timeIntervalSince1970],
                                   path: "\(String.users)/\(userId)")
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
