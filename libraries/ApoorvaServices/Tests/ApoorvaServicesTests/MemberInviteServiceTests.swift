import Testing
import Foundation
import ApoorvaModels
@testable import ApoorvaServices

struct MemberInviteServiceTests {
    private let account = AuthAccount(uid: "u1", email: "Anu@Shop.in", isEmailVerified: true)

    private func invite(email: String = "anu@shop.in", status: MemberInvite.Status = .pending) -> MemberInvite {
        MemberInvite(orgId: "org1", orgName: "Glitz", email: email, name: "Anu", role: .manager, storeIds: ["s1"],
                     invitedBy: "u0", invitedByName: "Kiran", status: status)
    }

    private func makeStore(with invite: MemberInvite) throws -> MockFirestoreStore {
        let store = MockFirestoreStore()
        try store.put(invite, at: "invites/\(invite.id)")
        return store
    }

    @Test func sendWritesTheInviteUnderOrgAndEmail() throws {
        let store = MockFirestoreStore()
        try MemberInviteService(store: store).send(invite())
        #expect(store.writes.first?.path == "invites/org1_anu@shop.in")
    }

    @Test func pendingInvitesForEmailSkipsOtherStatesAndNonInvites() async throws {
        let store = try makeStore(with:invite())
        try store.put(invite(email: "bob@shop.in"), at: "invites/org1_bob@shop.in")
        store.documents["invites/ABCD2345"] = ["token": "ABCD2345", "email": "anu@shop.in"]
        let found = try await MemberInviteService(store: store).pendingInvites(forEmail: " ANU@shop.in\n")
        #expect(found.map(\.id) == ["org1_anu@shop.in"])

        let revoked = try makeStore(with:invite(status: .revoked))
        #expect(try await MemberInviteService(store: revoked).pendingInvites(forEmail: "anu@shop.in").isEmpty)
    }

    @Test func acceptRejectsAnInviteThatWasRevokedMeanwhile() async throws {
        let store = try makeStore(with:invite(status: .revoked))
        await #expect(throws: MemberInviteError.self) {
            try await MemberInviteService(store: store)
                .accept(invite(), account: account, name: "Anu", existingOrgs: [], makeCurrent: true)
        }
        #expect(store.writes.isEmpty)
        #expect(store.updates.isEmpty)
    }

    @Test func acceptRejectsAnInviteAddressedToAnotherEmail() async throws {
        let store = try makeStore(with:invite(email: "bob@shop.in"))
        await #expect(throws: MemberInviteError.self) {
            try await MemberInviteService(store: store)
                .accept(invite(email: "bob@shop.in"), account: account, name: "Anu", existingOrgs: [], makeCurrent: true)
        }
        #expect(store.writes.isEmpty)
    }

    @Test func acceptCreatesAProfileWhenNoneExistsAndMarksTheInviteAccepted() async throws {
        let store = try makeStore(with:invite())
        try await MemberInviteService(store: store)
            .accept(invite(), account: account, name: "Anu", existingOrgs: [], makeCurrent: true)

        let write = try #require(store.writes.first { $0.path == "users/u1" })
        #expect(write.merge)
        #expect(write.data["id"] as? String == "u1")
        #expect(write.data["role"] as? String == AppUserRole.manager.rawValue)
        #expect(write.data["selectedOrganization"] != nil)
        #expect(write.data["assignedOrgIds"] is StoreArrayUnion)
        #expect(write.data["assignedOrgs"] is StoreArrayUnion)
        let membership = try #require((write.data["orgMembership"] as? [String: Any])?["org1"] as? [String: Any])
        #expect(membership["role"] as? String == OrgRole.manager.rawValue)
        #expect(store.updates.first?.path == "invites/org1_anu@shop.in")
        #expect(store.updates.first?.fields["status"] as? String == MemberInvite.Status.accepted.rawValue)
    }

    @Test func acceptLeavesAnExistingProfileAlone() async throws {
        let store = try makeStore(with:invite())
        store.documents["users/u1"] = ["id": "u1", "name": "Legacy Anu", "role": "admin", "createdAt": "31 March 2026"]
        let other = OrganizationSnapshot(orgId: "org0", name: "Old")
        try await MemberInviteService(store: store)
            .accept(invite(), account: account, name: "Anu", existingOrgs: [other], makeCurrent: false)

        let write = try #require(store.writes.first { $0.path == "users/u1" })
        for legacyField in ["id", "name", "email", "role", "status", "createdAt", "url", "isDeleted", "selectedOrganization"] {
            #expect(write.data[legacyField] == nil)
        }
        #expect(write.data["assignedOrgIds"] is StoreArrayUnion)
    }

    @Test func acceptDoesNotDuplicateAnAlreadyAssignedOrg() async throws {
        let store = try makeStore(with:invite())
        let existing = OrganizationSnapshot(orgId: "org1", name: "Glitz")
        try await MemberInviteService(store: store)
            .accept(invite(), account: account, name: "Anu", existingOrgs: [existing], makeCurrent: false)
        let write = try #require(store.writes.first { $0.path == "users/u1" })
        #expect(write.data["assignedOrgs"] == nil)
    }

    @Test func declineAndRoleUpdateWriteTheirFields() async throws {
        let store = MockFirestoreStore()
        let service = MemberInviteService(store: store)
        try await service.decline(invite())
        try await service.updateMembershipRole(userId: "u1", orgId: "org1", role: .cashier)
        #expect(store.updates[0].fields["status"] as? String == MemberInvite.Status.declined.rawValue)
        #expect(store.updates[1].path == "users/u1")
        #expect(store.updates[1].fields["orgMembership.org1.role"] as? String == OrgRole.cashier.rawValue)
    }
}
