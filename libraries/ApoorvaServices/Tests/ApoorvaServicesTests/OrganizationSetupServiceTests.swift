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

    @Test func createShopWritesOrgSettingsStoreAndOwnerProfile() async throws {
        let store = MockFirestoreStore()
        let orgId = try await OrganizationSetupService(store: store).createShop(shop(), owner: owner)
        let paths = Set(store.writes.map(\.path))

        #expect(paths.contains("organizations/\(orgId)"))
        #expect(paths.contains("organizations/\(orgId)/settings/org"))
        #expect(paths.contains("organizations/\(orgId)/stores/default"))
        #expect(!paths.contains("organizations/\(orgId)/members/u1"))
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
}
