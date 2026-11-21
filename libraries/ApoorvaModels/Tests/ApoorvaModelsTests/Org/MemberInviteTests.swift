import Testing
import Foundation
@testable import ApoorvaModels

struct MemberInviteTests {
    private func invite(email: String = " Anu@Shop.IN ") -> MemberInvite {
        MemberInvite(orgId: "org1", orgName: "Glitz", email: email, name: "Anu", role: .cashier, storeIds: ["default"],
                     invitedBy: "u0", invitedByName: "Kiran")
    }

    @Test func emailIsNormalizedAndDrivesTheId() {
        let invite = invite()
        #expect(invite.email == "anu@shop.in")
        #expect(invite.id == "org1_anu@shop.in")
        #expect(invite.isPending)
    }

    @Test func reinvitingTheSameEmailKeepsTheSameId() {
        #expect(invite(email: "ANU@shop.in").id == invite(email: "anu@shop.in").id)
    }

    @Test func onlyManagerAndCashierCanBeInvited() {
        #expect(MemberInvite.invitableRoles == [.manager, .cashier])
    }

    @Test func emailValidation() {
        #expect(MemberInvite.isValid(email: "a@b.co"))
        #expect(!MemberInvite.isValid(email: "a@b"))
        #expect(!MemberInvite.isValid(email: "@b.co"))
        #expect(!MemberInvite.isValid(email: "a b@c.co"))
        #expect(!MemberInvite.isValid(email: "a@@b.co"))
        #expect(!MemberInvite.isValid(email: ""))
        #expect(!MemberInvite.isValid(email: "anu/pos@shop.in"))
    }

    @Test func pastedNewlinesAreTrimmed() {
        #expect(MemberInvite.normalize(email: "Anu@Shop.IN\n") == "anu@shop.in")
        #expect(MemberInvite.isValid(email: "anu@shop.in\n"))
        #expect(!MemberInvite.isValid(email: "an\nu@shop.in"))
    }

    @Test func codableRoundTrip() throws {
        let original = invite()
        let decoded = try JSONDecoder().decode(MemberInvite.self, from: try JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
