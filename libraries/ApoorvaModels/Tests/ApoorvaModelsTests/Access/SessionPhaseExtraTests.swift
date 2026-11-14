//
//  SessionPhaseExtraTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("SessionPhase Extra Tests")
struct SessionPhaseExtraTests {
    private let account = AuthAccount(uid: "u1", email: "a@b.com", isEmailVerified: true)

    @Test("Phase keys identify each case")
    func keys() {
        #expect(SessionPhase.loading.key == "loading")
        #expect(SessionPhase.signedOut.key == "signedOut")
        #expect(SessionPhase.needsEmailVerification(account).key == "verify:u1")
        #expect(SessionPhase.needsProfile(account).key == "profile:u1")
        #expect(SessionPhase.needsOrgSetup(.pickLook).key == "setup:pickLook")
        #expect(SessionPhase.blocked(status: "suspended").key == "blocked:suspended")
        #expect(SessionPhase.forceUpdate(required: "2.0", current: "1.0").key == "forceUpdate")
        #expect(SessionPhase.ready(userId: "u1", orgId: "o1").key == "ready:u1:o1")
    }

    @Test("Blocking statuses")
    func blockingStatuses() {
        #expect(SessionPhaseReducer.blockingStatuses == ["blocked", "suspended", "deleted"])
    }

    @Test("Signed-in account without profile needs a profile when verified or verification not required")
    func needsProfile() {
        let phase = SessionPhaseReducer.phase(account: account, profile: nil, orgStatus: nil, orgSettings: nil,
                                              minAppVersion: "0.0.0", appVersion: "1.0.0", requireEmailVerification: true)
        #expect(phase == .needsProfile(account))

        let noEmail = AuthAccount(uid: "u2", email: nil, isEmailVerified: false)
        let phoneOnly = SessionPhaseReducer.phase(account: noEmail, profile: nil, orgStatus: nil, orgSettings: nil,
                                                  minAppVersion: "0.0.0", appVersion: "1.0.0", requireEmailVerification: true)
        #expect(phoneOnly == .needsProfile(noEmail))
    }

    @Test("Force update wins over missing profile")
    func forceUpdateFirst() {
        let phase = SessionPhaseReducer.phase(account: account, profile: nil, orgStatus: nil, orgSettings: nil,
                                              minAppVersion: "2.0.0", appVersion: "1.0.0", requireEmailVerification: true)
        #expect(phase == .forceUpdate(required: "2.0.0", current: "1.0.0"))
    }

    @Test("Settings without a vertical resume at choose vertical")
    func settingsWithoutVertical() {
        let profile = AppUser(id: "u1", name: "K", email: "a@b.com", role: .admin, status: "active", assignedOrgs: [],
                              createdAt: Date(),
                              selectedOrganization: OrganizationSnapshot(orgId: "o1", name: "Shop", accentColor: "#000000"),
                              url: "", updatedTimestamp: 0)
        let phase = SessionPhaseReducer.phase(account: account, profile: profile, orgStatus: nil, orgSettings: OrgSettings(),
                                              minAppVersion: "0.0.0", appVersion: "1.0.0", requireEmailVerification: true)
        #expect(phase == .needsOrgSetup(.chooseVertical))
    }

    @Test("AppVersion parses parts and tolerates junk")
    func appVersionParsing() {
        #expect(AppVersion("1.4.10").parts == [1, 4, 10])
        #expect(AppVersion("1.x.3").parts == [1, 0, 3])
        #expect(AppVersion("").parts.isEmpty)
        #expect(AppVersion("1.2.3-beta") > AppVersion("1.2.2"))
    }
}
