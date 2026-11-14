//
//  InviteTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Invite Model Tests")
struct InviteTests {

    private func makeInvite(createdAt: Date = Date(), expiresAt: Date? = nil, acceptedBy: String? = nil) -> Invite {
        Invite(orgId: "o1", orgName: "Shop", storeIds: ["s1"], storeName: "Main", role: OrgRole.allCases[0],
               name: "Ravi", phone: "9", invitedBy: "u1", invitedByName: "Asha",
               createdAt: createdAt, expiresAt: expiresAt, acceptedBy: acceptedBy)
    }

    @Test("Token is 8 unambiguous characters")
    func tokenFormat() {
        let allowed = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<50 {
            let token = Invite.makeToken()
            #expect(token.count == 8)
            #expect(Set(token).isSubset(of: allowed))
        }
    }

    @Test("Id is the token and link uses the join scheme")
    func idAndLink() {
        let invite = makeInvite()
        #expect(invite.id == invite.token)
        #expect(invite.link == "apoorva://join/\(invite.token)")
    }

    @Test("Expiry defaults to 72 hours after creation")
    func defaultExpiry() {
        let created = Date(timeIntervalSince1970: 1_000_000)
        #expect(makeInvite(createdAt: created).expiresAt == created.addingTimeInterval(72 * 3600))
    }

    @Test("isExpired reflects expiresAt")
    func expiry() {
        #expect(!makeInvite().isExpired)
        #expect(makeInvite(expiresAt: Date(timeIntervalSinceNow: -60)).isExpired)
    }

    @Test("isAccepted reflects acceptedBy")
    func accepted() {
        #expect(!makeInvite().isAccepted)
        #expect(makeInvite(acceptedBy: "u2").isAccepted)
    }

    @Test("Invite round-trips through Codable")
    func codable() throws {
        let invite = makeInvite(createdAt: Date(timeIntervalSince1970: 1_000_000))
        let decoded = try JSONDecoder().decode(Invite.self, from: JSONEncoder().encode(invite))
        #expect(decoded == invite)
    }
}
