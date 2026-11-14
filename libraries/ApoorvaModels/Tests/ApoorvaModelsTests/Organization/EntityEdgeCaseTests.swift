//
//  EntityEdgeCaseTests.swift
//  ApoorvaModels
//
//  Edge cases for AppUser, Organization, Account, InternalTransfer, DailyCashflowSummary.
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Entity Edge Case Tests")
struct EntityEdgeCaseTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - AppUser

    @Test("AppUser decoding an empty object applies fallbacks")
    func appUserEmpty() throws {
        let user = try decode(AppUser.self, "{}")
        #expect(!user.id.isEmpty)
        #expect(user.name == "Unknown User")
        #expect(user.email.isEmpty)
        #expect(user.role == .standard)
        #expect(user.status == "Active")
        #expect(user.assignedOrgs.isEmpty)
        #expect(user.selectedOrganization == nil)
        #expect(user.url.isEmpty)
        #expect(user.updatedTimestamp == 0)
        #expect(!user.isDeleted)
    }

    @Test("AppUser parses a string createdAt in the legacy format")
    func appUserStringDate() throws {
        let user = try decode(AppUser.self, #"{"createdAt":"31 March 2026 at 19:53:12 UTC+05:30"}"#)
        let expected = Date(timeIntervalSince1970: 1_774_966_992)
        #expect(abs(user.createdAt.timeIntervalSince(expected)) < 1)
    }

    @Test("AppUser falls back to now for an unparsable createdAt")
    func appUserBadDate() throws {
        let user = try decode(AppUser.self, #"{"createdAt":"not a date"}"#)
        #expect(abs(user.createdAt.timeIntervalSinceNow) < 5)
    }

    @Test("AppUser unknown role falls back to standard")
    func appUserUnknownRole() throws {
        #expect(try decode(AppUser.self, #"{"role":"wizard"}"#).role == .standard)
        #expect(try decode(AppUser.self, #"{"role":"super_admin"}"#).role == .superAdmin)
    }

    @Test("AppUser image URL is nil for an empty string and set for a valid one")
    func appUserImageURL() {
        func make(url: String) -> AppUser {
            AppUser(id: "1", name: "N", email: "e", role: .admin, status: "Active", assignedOrgs: [], createdAt: Date(), url: url)
        }
        #expect(make(url: "").imageURL == nil)
        #expect(make(url: "https://x.com/a.png").imageURL?.absoluteString == "https://x.com/a.png")
    }

    @Test("AppUser copyWith changes only the given fields")
    func appUserCopyWith() {
        let org = OrganizationSnapshot(orgId: "o1", name: "Shop")
        let user = AppUser(id: "1", name: "N", email: "e", role: .admin, status: "Active", assignedOrgs: [org],
                           createdAt: Date(timeIntervalSince1970: 10), selectedOrganization: org)
        let same = user.copyWith()
        #expect(same.id == "1")
        #expect(same.selectedOrganization == org)
        #expect(same.assignedOrgs == [org])

        let changed = user.copyWith(name: "New", role: .manager, isDeleted: true, updatedTimestamp: 9)
        #expect(changed.name == "New")
        #expect(changed.role == .manager)
        #expect(changed.isDeleted)
        #expect(changed.updatedTimestamp == 9)
        #expect(changed.email == "e")
    }

    @Test("AppUserSnapshot defaults orgRole and requires uid")
    func appUserSnapshot() throws {
        let snapshot = try decode(AppUserSnapshot.self, #"{"uid":"u","name":"N","email":"e"}"#)
        #expect(snapshot.orgRole == "staff")
        #expect(throws: (any Error).self) { _ = try decode(AppUserSnapshot.self, #"{"name":"N","email":"e"}"#) }
    }

    // MARK: - Organization / Snapshot / Account

    @Test("Organization decoding applies defaults but requires name and createdAt")
    func organizationDecoding() throws {
        let org = try decode(Organization.self, #"{"name":"Shop","createdAt":0}"#)
        #expect(org.id.isEmpty)
        #expect(org.status == "Active")
        #expect(org.minVersion == "1.0.0")
        #expect(org.currentTheme == "Default")
        #expect(org.accentColor == "#FF5733")
        #expect(org.accounts.isEmpty)
        #expect(org.establishedAtInMs == 0)
        #expect(!org.isDeleted)
        #expect(throws: (any Error).self) { _ = try decode(Organization.self, #"{"createdAt":0}"#) }
        #expect(throws: (any Error).self) { _ = try decode(Organization.self, #"{"name":"Shop"}"#) }
    }

    @Test("OrganizationSnapshot defaults accent, requires ids and hashes by value")
    func organizationSnapshot() throws {
        let snapshot = try decode(OrganizationSnapshot.self, #"{"orgId":"o1","name":"Shop"}"#)
        #expect(snapshot.accentColor == "#FF5733")
        #expect(snapshot.id == "o1")
        #expect(Set([snapshot, OrganizationSnapshot(orgId: "o1", name: "Shop")]).count == 1)
        #expect(throws: (any Error).self) { _ = try decode(OrganizationSnapshot.self, #"{"name":"Shop"}"#) }
    }

    @Test("Account decoding generates an id when missing and rejects bad types")
    func accountDecoding() throws {
        let account = try decode(Account.self, #"{"name":"Cash","type":"cash","currentBalance":10}"#)
        #expect(!account.id.isEmpty)
        #expect(!account.isDeleted)
        #expect(throws: (any Error).self) { _ = try decode(Account.self, #"{"name":"X","type":"crypto","currentBalance":1}"#) }
        #expect(throws: (any Error).self) { _ = try decode(Account.self, #"{"name":"X","type":"bank"}"#) }
    }

    @Test("Account allows negative balances")
    func accountNegative() throws {
        let account = try decode(Account.self, #"{"id":"a","name":"Bank","type":"bank","currentBalance":-250.5}"#)
        #expect(account.currentBalance == -250.5)
        #expect(account.id == "a")
    }

    @Test("InternalTransfer round-trips with sync defaults")
    func internalTransfer() throws {
        let transfer = InternalTransfer(id: "t", fromAccountId: "a", toAccountId: "b", amount: 10, transferType: "deposit",
                                        timestamp: Date(timeIntervalSince1970: 100))
        let decoded = try JSONDecoder().decode(InternalTransfer.self, from: JSONEncoder().encode(transfer))
        #expect(decoded.fromAccountId == "a")
        #expect(decoded.toAccountId == "b")
        #expect(decoded.amount == 10)
        #expect(!decoded.isDeleted)
    }

    // MARK: - DailyCashflowSummary

    @Test("Empty balances total zero and id is the day key")
    func summaryEmpty() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12))!
        let summary = DailyCashflowSummary(date: date, openingBalances: [], closingBalances: [], updatedAt: 0, locked: false)
        #expect(summary.totalOpening == 0)
        #expect(summary.totalClosing == 0)
        #expect(summary.id == date.dayKey)
        #expect(summary.id == "05-01-2026")
    }

    @Test("Totals sum negative and positive balances")
    func summaryTotals() {
        let summary = DailyCashflowSummary(
            date: Date(),
            openingBalances: [AccountBalance(id: "a", name: "Cash", balance: 100), AccountBalance(id: "b", name: "Bank", balance: -30)],
            closingBalances: [AccountBalance(id: "a", name: "Cash", balance: 0.5)],
            updatedAt: 0, locked: true)
        #expect(summary.totalOpening == 70)
        #expect(summary.totalClosing == 0.5)
        #expect(summary.locked)
    }

    @Test("Decoding without closing balances yields an empty list")
    func summaryDecodeMissingClosing() throws {
        let json = #"{"id":"05-01-2026","date":0,"openingBalances":[],"updatedAt":1,"locked":false}"#
        let summary = try decode(DailyCashflowSummary.self, json)
        #expect(summary.closingBalances.isEmpty)
        #expect(summary.id == "05-01-2026")
        #expect(throws: (any Error).self) { _ = try decode(DailyCashflowSummary.self, #"{"id":"x"}"#) }
    }

    @Test("copyWith keeps unchanged fields and recomputes the id when the date changes")
    func summaryCopyWith() {
        let first = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12))!
        let second = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 12))!
        let summary = DailyCashflowSummary(date: first, openingBalances: [AccountBalance(id: "a", name: "Cash", balance: 1)],
                                           closingBalances: [], updatedAt: 5, locked: false)
        let same = summary.copyWith()
        #expect(same.id == summary.id)
        #expect(same.totalOpening == 1)

        let moved = summary.copyWith(date: second, locked: true)
        #expect(moved.id == "06-01-2026")
        #expect(moved.locked)
        #expect(moved.updatedAt == 5)
    }
}
