//
//  AppUserTests.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 06/11/26.
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("AppUser Model Tests")
struct AppUserTests {

    private let orgJSON = ##"{"orgId": "org-1", "name": "Apoorva Store", "accentColor": "#112233"}"##

    private func decodeUser(_ json: String) throws -> AppUser {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(AppUser.self, from: Data(json.utf8))
    }

    private func decodeSnapshot(_ json: String) throws -> OrganizationSnapshot {
        try JSONDecoder().decode(OrganizationSnapshot.self, from: Data(json.utf8))
    }

    private func makeUser(url: String = "", updatedTimestamp: TimeInterval = 0) throws -> AppUser {
        AppUser(
            id: "user-1",
            name: "Asha",
            email: "asha@example.com",
            role: .manager,
            status: "Active",
            assignedOrgs: [try decodeSnapshot(orgJSON)],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
            isDeleted: false,
            selectedOrganization: nil,
            url: url,
            updatedTimestamp: updatedTimestamp
        )
    }

    // MARK: - AppUserSnapshot

    @Test("AppUserSnapshot decodes all keys")
    func testSnapshotFullDecoding() throws {
        let json = #"{"uid": "u1", "name": "Asha", "email": "a@x.com", "orgRole": "admin"}"#
        let snapshot = try JSONDecoder().decode(AppUserSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.uid == "u1")
        #expect(snapshot.name == "Asha")
        #expect(snapshot.email == "a@x.com")
        #expect(snapshot.orgRole == "admin")
    }

    @Test("AppUserSnapshot defaults orgRole to staff when missing")
    func testSnapshotOrgRoleDefault() throws {
        let json = #"{"uid": "u1", "name": "Asha", "email": "a@x.com"}"#
        let snapshot = try JSONDecoder().decode(AppUserSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.orgRole == "staff")
    }

    @Test("AppUserSnapshot throws when a required key is missing", arguments: [
        #"{"name": "Asha", "email": "a@x.com"}"#,
        #"{"uid": "u1", "email": "a@x.com"}"#,
        #"{"uid": "u1", "name": "Asha"}"#
    ])
    func testSnapshotRequiredKeys(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppUserSnapshot.self, from: Data(json.utf8))
        }
    }

    // MARK: - AppUserRole

    @Test("AppUserRole raw values map to the expected cases")
    func testRoleRawValues() {
        #expect(AppUserRole.standard.rawValue == "standard")
        #expect(AppUserRole.admin.rawValue == "admin")
        #expect(AppUserRole.manager.rawValue == "manager")
        #expect(AppUserRole.superAdmin.rawValue == "super_admin")
    }

    @Test("AppUserRole throws for an unknown raw value")
    func testRoleUnknownValueThrows() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppUserRole.self, from: Data(#""owner""#.utf8))
        }
    }

    // MARK: - AppUser decoding

    @Test("AppUser decodes with every default when the object is empty")
    func testEmptyObjectDefaults() throws {
        let user = try decodeUser("{}")

        #expect(!user.id.isEmpty)
        #expect(user.name == "Unknown User")
        #expect(user.email == "")
        #expect(user.role == .standard)
        #expect(user.status == "Active")
        #expect(user.assignedOrgs.isEmpty)
        #expect(user.selectedOrganization == nil)
        #expect(user.url == "")
        #expect(user.updatedTimestamp == 0)
        #expect(user.isDeleted == false)
        #expect(user.updatedAt.timeIntervalSinceNow > -5)
        #expect(user.createdAt.timeIntervalSinceNow > -5)
    }

    @Test("AppUser decodes a complete payload")
    func testFullDecoding() throws {
        let json = """
        {
            "id": "user-9",
            "name": "Ravi",
            "email": "ravi@example.com",
            "role": "super_admin",
            "status": "Suspended",
            "assignedOrgs": [\(orgJSON)],
            "createdAt": 1700000000,
            "updatedAt": 1700000500,
            "isDeleted": true,
            "selectedOrganization": \(orgJSON),
            "url": "https://example.com/avatar.png",
            "updatedTimestamp": 123.5
        }
        """
        let user = try decodeUser(json)

        #expect(user.id == "user-9")
        #expect(user.name == "Ravi")
        #expect(user.email == "ravi@example.com")
        #expect(user.role == .superAdmin)
        #expect(user.status == "Suspended")
        #expect(user.assignedOrgs.count == 1)
        #expect(user.assignedOrgs.first?.orgId == "org-1")
        #expect(user.createdAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(user.updatedAt == Date(timeIntervalSince1970: 1_700_000_500))
        #expect(user.isDeleted == true)
        #expect(user.selectedOrganization?.name == "Apoorva Store")
        #expect(user.url == "https://example.com/avatar.png")
        #expect(user.updatedTimestamp == 123.5)
    }

    @Test("AppUser reads updatedTimestamp from its own key, independent of url")
    func testUpdatedTimestampUsesOwnKey() throws {
        let json = #"{"url": "https://example.com/a.png", "updatedTimestamp": 987.25}"#
        let user = try decodeUser(json)

        #expect(user.updatedTimestamp == 987.25)
        #expect(user.url == "https://example.com/a.png")
    }

    @Test("AppUser falls back to 0 for updatedTimestamp when a numeric url is present")
    func testUpdatedTimestampIgnoresNumericURL() throws {
        let user = try decodeUser(#"{"url": 55}"#)

        #expect(user.updatedTimestamp == 0)
        #expect(user.url == "")
    }

    @Test("AppUser falls back to defaults when fields have the wrong type")
    func testWrongTypeFallbacks() throws {
        let json = """
        {
            "id": 1,
            "name": 2,
            "email": 3,
            "role": "owner",
            "status": 4,
            "assignedOrgs": "not-an-array",
            "updatedAt": "garbage",
            "isDeleted": "yes",
            "selectedOrganization": "not-an-object",
            "url": 5,
            "updatedTimestamp": "abc"
        }
        """
        let user = try decodeUser(json)

        #expect(!user.id.isEmpty)
        #expect(user.name == "Unknown User")
        #expect(user.email == "")
        #expect(user.role == .standard)
        #expect(user.status == "Active")
        #expect(user.assignedOrgs.isEmpty)
        #expect(user.updatedAt.timeIntervalSinceNow > -5)
        #expect(user.isDeleted == false)
        #expect(user.selectedOrganization == nil)
        #expect(user.url == "")
        #expect(user.updatedTimestamp == 0)
    }

    // MARK: - createdAt branches

    @Test("createdAt uses a numeric date value when present")
    func testCreatedAtFromDate() throws {
        let user = try decodeUser(#"{"createdAt": 1700000000}"#)

        #expect(user.createdAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("createdAt parses the string format with a zero-padded offset")
    func testCreatedAtStringWithPaddedOffset() throws {
        let user = try decodeUser(#"{"createdAt": "31 March 2026 at 19:53:12 UTC+05:30"}"#)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 19_800))
        let expected = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 31, hour: 19, minute: 53, second: 12
        )))

        #expect(user.createdAt == expected)
    }

    @Test("createdAt repairs a single-digit offset hour before parsing")
    func testCreatedAtStringWithUnpaddedOffset() throws {
        let user = try decodeUser(#"{"createdAt": "31 March 2026 at 19:53:12 UTC+5:30"}"#)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 19_800))
        let expected = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 31, hour: 19, minute: 53, second: 12
        )))

        #expect(user.createdAt == expected)
    }

    @Test("createdAt falls back to now when the string cannot be parsed")
    func testCreatedAtUnparseableString() throws {
        let user = try decodeUser(#"{"createdAt": "not a date"}"#)

        #expect(abs(user.createdAt.timeIntervalSinceNow) < 5)
    }

    @Test("createdAt falls back to now when the value has the wrong type")
    func testCreatedAtWrongType() throws {
        let user = try decodeUser(#"{"createdAt": [1, 2, 3]}"#)

        #expect(abs(user.createdAt.timeIntervalSinceNow) < 5)
    }

    @Test("createdAt falls back to now when the key is null")
    func testCreatedAtNull() throws {
        let user = try decodeUser(#"{"createdAt": null}"#)

        #expect(abs(user.createdAt.timeIntervalSinceNow) < 5)
    }

    // MARK: - selectedOrganization

    @Test("selectedOrganization is nil when absent")
    func testSelectedOrganizationAbsent() throws {
        let user = try decodeUser("{}")

        #expect(user.selectedOrganization == nil)
    }

    @Test("selectedOrganization decodes when present")
    func testSelectedOrganizationPresent() throws {
        let user = try decodeUser(#"{"selectedOrganization": \#(orgJSON)}"#)

        #expect(user.selectedOrganization?.orgId == "org-1")
    }

    // MARK: - Memberwise init

    @Test("Memberwise init applies defaults for optional parameters")
    func testMemberwiseDefaults() throws {
        let user = AppUser(
            id: "u",
            name: "N",
            email: "e",
            role: .admin,
            status: "Active",
            assignedOrgs: [],
            createdAt: Date(timeIntervalSince1970: 0)
        )

        #expect(user.updatedAt.timeIntervalSinceNow > -5)
        #expect(user.isDeleted == false)
        #expect(user.selectedOrganization == nil)
        #expect(user.url == "")
        #expect(user.updatedTimestamp == 0)
    }

    // MARK: - imageURL

    @Test("imageURL is nil for an empty url string")
    func testImageURLEmpty() throws {
        let user = try makeUser(url: "")

        #expect(user.imageURL == nil)
    }

    @Test("imageURL is built from a valid url string")
    func testImageURLValid() throws {
        let user = try makeUser(url: "https://example.com/avatar.png")

        #expect(user.imageURL?.absoluteString == "https://example.com/avatar.png")
    }

    // MARK: - copyWith

    @Test("copyWith with no arguments preserves every field")
    func testCopyWithNoArguments() throws {
        let original = try makeUser(url: "https://x.com/a.png", updatedTimestamp: 42)
        let copy = original.copyWith()

        #expect(copy.id == original.id)
        #expect(copy.name == original.name)
        #expect(copy.email == original.email)
        #expect(copy.role == original.role)
        #expect(copy.status == original.status)
        #expect(copy.assignedOrgs.count == original.assignedOrgs.count)
        #expect(copy.createdAt == original.createdAt)
        #expect(copy.updatedAt == original.updatedAt)
        #expect(copy.isDeleted == original.isDeleted)
        #expect(copy.selectedOrganization == nil)
        #expect(copy.url == original.url)
        #expect(copy.updatedTimestamp == original.updatedTimestamp)
    }

    @Test("copyWith replaces every field when arguments are supplied")
    func testCopyWithAllArguments() throws {
        let original = try makeUser()
        let newOrg = try decodeSnapshot(##"{"orgId": "org-2", "name": "Branch", "accentColor": "#000000"}"##)
        let newCreated = Date(timeIntervalSince1970: 1_600_000_000)
        let newUpdated = Date(timeIntervalSince1970: 1_650_000_000)

        let copy = original.copyWith(
            id: "user-2",
            name: "Meera",
            email: "meera@example.com",
            role: .superAdmin,
            status: "Inactive",
            assignedOrgs: [newOrg],
            createdAt: newCreated,
            updatedAt: newUpdated,
            isDeleted: true,
            selectedOrganization: newOrg,
            url: "https://example.com/new.png",
            updatedTimestamp: 77
        )

        #expect(copy.id == "user-2")
        #expect(copy.name == "Meera")
        #expect(copy.email == "meera@example.com")
        #expect(copy.role == .superAdmin)
        #expect(copy.status == "Inactive")
        #expect(copy.assignedOrgs.first?.orgId == "org-2")
        #expect(copy.createdAt == newCreated)
        #expect(copy.updatedAt == newUpdated)
        #expect(copy.isDeleted == true)
        #expect(copy.selectedOrganization?.orgId == "org-2")
        #expect(copy.url == "https://example.com/new.png")
        #expect(copy.updatedTimestamp == 77)
    }

    @Test("copyWith does not mutate the original instance")
    func testCopyWithDoesNotMutateOriginal() throws {
        let original = try makeUser()
        _ = original.copyWith(name: "Changed")

        #expect(original.name == "Asha")
    }
}
