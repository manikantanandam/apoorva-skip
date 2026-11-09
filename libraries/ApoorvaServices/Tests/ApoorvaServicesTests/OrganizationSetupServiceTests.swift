//
//  OrganizationSetupServiceTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import FirebaseFirestore
import ApoorvaModels
@testable import ApoorvaServices

struct OrganizationSetupServiceTests {
    private let owner = AuthAccount(uid: "u1", email: "k@shop.in", isEmailVerified: true)

    private func shop() -> NewShop {
        NewShop(ownerName: "Kiran", shopName: "Glitz Gifts", phone: "9848012345", address: "Ameerpet",
                billPrefix: "GG-", vertical: .fancy, theme: OrgSettings.Theme(accent: .plum, style: .bold))
    }

    @Test func createShopWritesOrgSettingsStoreMemberAndProfile() async throws {
        let store = MockFirestoreStore()
        let orgId = try await OrganizationSetupService(store: store).createShop(shop(), owner: owner)
        let paths = Set(store.writes.map(\.path))

        #expect(paths.contains("organizations/\(orgId)"))
        #expect(paths.contains("organizations/\(orgId)/settings/org"))
        #expect(paths.contains("organizations/\(orgId)/stores/default"))
        #expect(paths.contains("organizations/\(orgId)/members/u1"))
        #expect(paths.contains("users/u1"))

        let org = try #require(store.documents["organizations/\(orgId)"])
        #expect(org["name"] as? String == "Glitz Gifts")
        #expect(org["status"] as? String == "Active")
        #expect((org["accounts"] as? [[String: Any]])?.count == 2)

        let profile = try #require(store.documents["users/u1"])
        #expect(profile["role"] as? String == AppUserRole.admin.rawValue)
        #expect((profile["selectedOrganization"] as? [String: Any])?["orgId"] as? String == orgId)
        #expect(profile["assignedOrgIds"] as? [String] == [orgId])

        let settings = try Firestore.Decoder().decode(OrgSettings.self, from: try #require(store.documents["organizations/\(orgId)/settings/org"]))
        #expect(settings.profile.vertical == .fancy)
        #expect(settings.profile.setupCompletedAt != nil)
        #expect(settings.theme.style == .bold)
        #expect(settings.plan.tier == .trial)
    }

    @Test func acceptInviteAddsMembershipAndMarksInviteUsed() async throws {
        let store = MockFirestoreStore()
        let invite = Invite(token: "ABCD2345", orgId: "org1", orgName: "Glitz", storeIds: ["default"], storeName: "Glitz",
                            role: .manager, name: "Anu", phone: "9000000000", invitedBy: "u0", invitedByName: "Kiran")
        try await OrganizationSetupService(store: store).acceptInvite(invite, account: owner, name: "Anu", existingOrgs: [])

        #expect(store.documents["organizations/org1/members/u1"] != nil)
        #expect(store.documents["users/u1"]?["role"] as? String == AppUserRole.manager.rawValue)
        #expect(store.updates.first?.path == "invites/ABCD2345")
        #expect(store.updates.first?.fields["acceptedBy"] as? String == "u1")
    }

    @Test func invitesAreValidFor72Hours() {
        let invite = Invite(orgId: "o", orgName: "O", storeIds: [], storeName: "", role: .cashier, name: "", phone: "",
                            invitedBy: "", invitedByName: "", createdAt: Date().addingTimeInterval(-73 * 3600))
        #expect(invite.isExpired)
        #expect(invite.token.count == 8)
        #expect(invite.link.hasPrefix("apoorva://join/"))
    }
}
