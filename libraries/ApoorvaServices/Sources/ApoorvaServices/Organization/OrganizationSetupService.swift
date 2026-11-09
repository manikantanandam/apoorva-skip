//
//  OrganizationSetupService.swift
//  ApoorvaServices
//

import Foundation
import FirebaseFirestore
import ApoorvaModels

/// What onboarding collected for a new shop.
public struct NewShop: Sendable {
    public let ownerName: String
    public let shopName: String
    public let phone: String
    public let address: String
    public let billPrefix: String
    public let vertical: Vertical
    public let theme: OrgSettings.Theme
    public let trialDays: Int

    public init(ownerName: String, shopName: String, phone: String, address: String, billPrefix: String,
                vertical: Vertical, theme: OrgSettings.Theme, trialDays: Int = 30) {
        self.ownerName = ownerName
        self.shopName = shopName
        self.phone = phone
        self.address = address
        self.billPrefix = billPrefix
        self.vertical = vertical
        self.theme = theme
        self.trialDays = trialDays
    }
}

public protocol OrganizationSetupServicing: Sendable {
    /// Creates the org (legacy-compatible shape), its settings, default store, owner membership and
    /// the owner's `users/{uid}` profile. Returns the new org id.
    func createShop(_ shop: NewShop, owner: AuthAccount) async throws -> String
    func fetchInvite(token: String) async throws -> Invite?
    func createInvite(_ invite: Invite) throws
    /// Joins the invite's org: membership doc, profile assigned to the org, invite marked accepted.
    func acceptInvite(_ invite: Invite, account: AuthAccount, name: String, existingOrgs: [OrganizationSnapshot]) async throws
    func updateOrganizationStatus(orgId: String, status: String, reason: String) async throws
    func fetchAllOrganizations() async throws -> [Organization]
}

public final class OrganizationSetupService: OrganizationSetupServicing, @unchecked Sendable {
    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func createShop(_ shop: NewShop, owner: AuthAccount) async throws -> String {
        let orgId = UUID().uuidString
        let now = Date()

        // Same shape the legacy app writes (docs/12 §3): Timestamp createdAt, embedded accounts.
        let organization = Organization(
            id: orgId,
            name: shop.shopName,
            status: "Active",
            createdAt: now,
            minVersion: "1.0.0",
            currentTheme: "Default",
            accentColor: "#FF5733",
            accounts: [
                Account(name: "Cash", type: .cash, currentBalance: 0),
                Account(name: "UPI", type: .upi, currentBalance: 0)
            ],
            updatedAt: now,
            establishedAtInMs: now.timeIntervalSince1970
        )
        try store.setData(try Firestore.Encoder().encode(organization), path: "\(String.organizations)/\(orgId)", merge: false)

        var settings = OrgSettings()
        settings.profile = OrgSettings.Profile(shopName: shop.shopName, phone: shop.phone, address: shop.address,
                                               billPrefix: shop.billPrefix, vertical: shop.vertical, setupCompletedAt: now)
        settings.theme = shop.theme
        settings.flags.org = shop.vertical.defaultFlags
        settings.plan = OrgSettings.Plan(tier: .trial, trialStartedAt: now)
        try upsert(settings, orgId: orgId)

        try upsert(Store.defaultStore(name: shop.shopName, vertical: shop.vertical, billPrefix: shop.billPrefix), orgId: orgId)
        try upsert(Member(id: owner.uid, name: shop.ownerName, phone: shop.phone, email: owner.email ?? "", role: .owner), orgId: orgId)

        let snapshot = OrganizationSnapshot(orgId: orgId, name: shop.shopName)
        let encodedSnapshot = try Firestore.Encoder().encode(snapshot)
        try store.setData([
            "id": owner.uid,
            "name": shop.ownerName,
            "email": owner.email ?? "",
            "role": AppUserRole.admin.rawValue,
            "status": "active",
            "assignedOrgs": [encodedSnapshot],
            "assignedOrgIds": [orgId],
            "selectedOrganization": encodedSnapshot,
            "createdAt": now,
            "updatedAt": now,
            "updatedTimestamp": now.timeIntervalSince1970,
            "url": "",
            "isDeleted": false
        ], path: "\(String.users)/\(owner.uid)", merge: true)
        return orgId
    }

    public func fetchInvite(token: String) async throws -> Invite? {
        guard let document = try await store.getDocument(path: "invites/\(token.uppercased())") else { return nil }
        return try Firestore.Decoder().decode(Invite.self, from: document.data)
    }

    public func createInvite(_ invite: Invite) throws {
        try store.setData(try Firestore.Encoder().encode(invite), path: "invites/\(invite.token)", merge: false)
    }

    public func acceptInvite(_ invite: Invite, account: AuthAccount, name: String, existingOrgs: [OrganizationSnapshot]) async throws {
        let now = Date()
        try upsert(Member(id: account.uid, name: name, phone: invite.phone, email: account.email ?? "",
                          role: invite.role, storeIds: invite.storeIds, joinedAt: now), orgId: invite.orgId)

        let snapshot = OrganizationSnapshot(orgId: invite.orgId, name: invite.orgName)
        let orgs = existingOrgs.filter { $0.orgId != invite.orgId } + [snapshot]
        let legacyRole: AppUserRole = switch invite.role {
        case .owner: .admin
        case .manager: .manager
        case .cashier, .accountant: .standard
        }
        try store.setData([
            "id": account.uid,
            "name": name,
            "email": account.email ?? "",
            "role": legacyRole.rawValue,
            "status": "active",
            "assignedOrgs": try orgs.map { try Firestore.Encoder().encode($0) },
            "assignedOrgIds": orgs.map(\.orgId),
            "selectedOrganization": try Firestore.Encoder().encode(snapshot),
            "updatedAt": now,
            "updatedTimestamp": now.timeIntervalSince1970,
            "isDeleted": false
        ], path: "\(String.users)/\(account.uid)", merge: true)

        try await store.updateData(["acceptedBy": account.uid, "acceptedAt": now], path: "invites/\(invite.token)")
    }

    public func updateOrganizationStatus(orgId: String, status: String, reason: String) async throws {
        try await store.updateData([
            "status": status,
            "statusReason": reason,
            "updatedAt": Date()
        ], path: "\(String.organizations)/\(orgId)")
    }

    public func fetchAllOrganizations() async throws -> [Organization] {
        try await store.fetch(Organization.self, collection: String.organizations)
    }

    private func upsert<Document: OrgDocument>(_ document: Document, orgId: String) throws {
        try OrgCollectionService<Document>(store: store).upsert(document, orgId: orgId)
    }
}
