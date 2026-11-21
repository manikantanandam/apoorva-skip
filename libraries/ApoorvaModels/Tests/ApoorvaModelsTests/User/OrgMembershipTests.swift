import Testing
import Foundation
@testable import ApoorvaModels

struct OrgMembershipTests {
    private func user(role: AppUserRole = .standard, isDeleted: Bool = false,
                      orgMembership: [String: OrgMembership] = [:]) -> AppUser {
        AppUser(id: "u1", name: "Anu", email: "anu@shop.in", role: role, status: "Active", assignedOrgs: [],
                createdAt: Date(timeIntervalSince1970: 100), isDeleted: isDeleted, orgMembership: orgMembership)
    }

    @Test func legacyUserKeepsRoleFromLegacyFieldAndHasAllStoreAccess() {
        let member = user(role: .admin).member(in: "org1")
        #expect(member.id == "u1")
        #expect(member.role == .owner)
        #expect(member.storeIds.isEmpty)
        #expect(member.isActive)
        #expect(member.joinedAt == Date(timeIntervalSince1970: 100))
    }

    @Test func orgMembershipEntryOverridesLegacyRoleForThatOrgOnly() {
        let entry = OrgMembership(role: .cashier, storeIds: ["s1"], phone: "9", baseSalary: 12000, commissionPercent: 5)
        let user = user(role: .admin, orgMembership: ["org1": entry])
        let member = user.member(in: "org1")
        #expect(member.role == .cashier)
        #expect(member.storeIds == ["s1"])
        #expect(member.phone == "9")
        #expect(member.baseSalary == 12000)
        #expect(member.commissionPercent == 5)
        #expect(user.member(in: "other").role == .owner)
    }

    @Test func deletedUsersAreInactiveUnlessTheEntrySaysOtherwise() {
        #expect(!user(isDeleted: true).member(in: "org1").isActive)
        let entry = OrgMembership(isActive: false)
        #expect(!user(orgMembership: ["org1": entry]).member(in: "org1").isActive)
    }

    @Test func profileWithoutOrgMembershipStillDecodes() throws {
        let json = #"{"id":"u1","name":"Anu","email":"a@b.c","role":"manager"}"#
        let decoded = try JSONDecoder().decode(AppUser.self, from: Data(json.utf8))
        #expect(decoded.orgMembership.isEmpty)
        #expect(decoded.member(in: "org1").role == .manager)
    }
}
