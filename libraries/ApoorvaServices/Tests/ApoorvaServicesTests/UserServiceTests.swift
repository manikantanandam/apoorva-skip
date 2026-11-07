//
//  UserServiceTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import FirebaseFirestore
import ApoorvaModels
@testable import ApoorvaServices

struct StubAuthService: AuthServicing {
    let users: [AppUser?]

    var currentUserStream: AsyncStream<AppUser?> {
        let users = users
        return AsyncStream { continuation in
            users.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func login(email: String, password: String) async throws {}
    func logout() throws {}
}

func makeAppUser(_ id: String) throws -> AppUser {
    let data = try JSONSerialization.data(withJSONObject: ["id": id, "name": "Test", "email": "t@t.com"])
    return try JSONDecoder().decode(AppUser.self, from: data)
}

func makeOrgSnapshot(_ id: String) throws -> OrganizationSnapshot {
    let data = try JSONSerialization.data(withJSONObject: ["orgId": id, "name": id])
    return try JSONDecoder().decode(OrganizationSnapshot.self, from: data)
}

@MainActor
struct UserServiceTests {
    private func firstSessionValue(_ service: UserService) async -> AppUser?? {
        var iterator = service.userSessionStream.makeAsyncIterator()
        return await iterator.next()
    }

    @Test func loggedOutAuthYieldsNilSession() async throws {
        let service = UserService(authService: StubAuthService(users: [nil]), store: MockFirestoreStore())
        let value = await firstSessionValue(service)
        #expect(value != nil && (value ?? nil) == nil)
        #expect(service.currentUser == nil)
    }

    @Test func authenticatedUserLoadsFullProfile() async throws {
        let store = MockFirestoreStore()
        store.documents["users/u1"] = ["id": "u1", "name": "Full Name", "email": "u@u.com"]
        let service = UserService(authService: StubAuthService(users: [try makeAppUser("u1")]), store: store)
        let value = await firstSessionValue(service)
        #expect(value??.name == "Full Name")
        #expect(service.currentUser?.name == "Full Name")
    }

    @Test func missingProfileYieldsNilSession() async throws {
        let service = UserService(authService: StubAuthService(users: [try makeAppUser("ghost")]), store: MockFirestoreStore())
        let value = await firstSessionValue(service)
        #expect(value != nil && (value ?? nil) == nil)
        #expect(service.currentUser == nil)
    }

    @Test func fetchUserProfileThrowsWhenMissing() async {
        let service = UserService(authService: StubAuthService(users: []), store: MockFirestoreStore())
        await #expect(throws: (any Error).self) { try await service.fetchUserProfile(uid: "nope") }
    }

    @Test func updateSelectedOrganizationWritesUserDocument() async throws {
        let store = MockFirestoreStore()
        let service = UserService(authService: StubAuthService(users: []), store: store)
        try await service.updateSelectedOrganization(for: try makeAppUser("u1"), organization: try makeOrgSnapshot("orgX"))
        #expect(store.updates.first?.path == "users/u1")
        #expect(store.updates.first?.fields["selectedOrganization"] != nil)
        #expect(store.updates.first?.fields["updatedTimestamp"] != nil)
    }
}
