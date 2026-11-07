//
//  UserAndOrganizationViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
@testable import ApoorvaModules

final class MockUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    struct MockError: Error {}

    var currentUser: AppUser?
    var listUsersResult: [AppUser] = []
    var updatedRoles: [(id: String, role: AppUserRole)] = []
    var updatedOrgs: [String] = []
    var shouldThrowOnLoad = false
    var shouldThrowOnMutate = false

    func getCurrentUser() async throws -> AppUser {
        if shouldThrowOnLoad { throw MockError() }
        guard let currentUser else { throw MockError() }
        return currentUser
    }

    func getUser(id: String) async throws -> AppUser? { currentUser }

    func setUser(user: AppUser) async throws {}

    func updateUser(user: AppUser) async throws {}

    func deleteUser(id: String) async {}

    func updateSelectedOrganization(for user: AppUser, organization: OrganizationSnapshot) async throws {
        if shouldThrowOnMutate { throw MockError() }
        updatedOrgs.append(organization.orgId)
        currentUser = user.copyWith(selectedOrganization: organization)
    }

    func listUsers(orgId: String) async throws -> [AppUser] {
        if shouldThrowOnLoad { throw MockError() }
        return listUsersResult
    }

    func updateUserRole(id: String, role: AppUserRole) async throws {
        if shouldThrowOnMutate { throw MockError() }
        updatedRoles.append((id, role))
    }
}

func makeModuleUser(id: String = "u1", orgId: String? = nil) throws -> AppUser {
    var json: [String: Any] = ["id": id, "name": "Test User", "email": "\(id)@test.com"]
    if let orgId {
        json["selectedOrganization"] = ["orgId": orgId, "name": "Org"]
    }
    let data = try JSONSerialization.data(withJSONObject: json)
    return try JSONDecoder().decode(AppUser.self, from: data)
}

@MainActor
struct UserListViewModelTests {
    @Test func loadPopulatesUsersForSelectedOrg() async throws {
        let repository = MockUserRepository()
        repository.currentUser = try makeModuleUser(id: "admin1", orgId: "orgX")
        repository.listUsersResult = [try makeModuleUser(id: "member1"), try makeModuleUser(id: "member2")]
        let vm = UserListViewModel(userRepository: repository)
        await vm.load()
        #expect(vm.users.map(\.id) == ["member1", "member2"])
        #expect(vm.currentUserId == "admin1")
        #expect(vm.errorMessage == nil)
    }

    @Test func loadResultsInEmptyListWhenNoOrgSelected() async throws {
        let repository = MockUserRepository()
        repository.currentUser = try makeModuleUser(id: "admin1")
        let vm = UserListViewModel(userRepository: repository)
        await vm.load()
        #expect(vm.users.isEmpty)
    }

    @Test func filteredUsersMatchesNameOrEmail() async throws {
        let repository = MockUserRepository()
        let vm = UserListViewModel(userRepository: repository)
        vm.users = [try makeModuleUser(id: "alice"), try makeModuleUser(id: "bob")]
        vm.searchText = "alice"
        #expect(vm.filteredUsers.map(\.id) == ["alice"])
    }

    @Test func updateRoleUpdatesLocalListOnSuccess() async throws {
        let repository = MockUserRepository()
        let vm = UserListViewModel(userRepository: repository)
        let user = try makeModuleUser(id: "member1")
        vm.users = [user]
        await vm.updateRole(for: user, role: .admin)
        #expect(repository.updatedRoles.map(\.id) == ["member1"])
        #expect(vm.users.first?.role == .admin)
    }

    @Test func updateRoleSetsErrorMessageOnFailure() async throws {
        let repository = MockUserRepository()
        repository.shouldThrowOnMutate = true
        let vm = UserListViewModel(userRepository: repository)
        let user = try makeModuleUser(id: "member1")
        vm.users = [user]
        await vm.updateRole(for: user, role: .admin)
        #expect(vm.errorMessage != nil)
    }
}

@MainActor
struct OrganizationListViewModelTests {
    @Test func loadPopulatesOrganizationsAndSelectedId() async throws {
        let repository = MockUserRepository()
        repository.currentUser = try makeModuleUser(id: "u1", orgId: "orgX")
        let vm = OrganizationListViewModel(userRepository: repository)
        await vm.load()
        #expect(vm.selectedOrgId == "orgX")
    }

    @Test func selectCallsUpdateSelectedOrganizationAndUpdatesState() async throws {
        let repository = MockUserRepository()
        repository.currentUser = try makeModuleUser(id: "u1")
        let vm = OrganizationListViewModel(userRepository: repository)
        let org = try JSONDecoder().decode(
            OrganizationSnapshot.self,
            from: JSONSerialization.data(withJSONObject: ["orgId": "orgY", "name": "Org Y"])
        )
        let success = await vm.select(org)
        #expect(success)
        #expect(repository.updatedOrgs == ["orgY"])
        #expect(vm.selectedOrgId == "orgY")
    }

    @Test func selectReturnsFalseAndSetsErrorOnFailure() async throws {
        let repository = MockUserRepository()
        repository.currentUser = try makeModuleUser(id: "u1")
        repository.shouldThrowOnMutate = true
        let vm = OrganizationListViewModel(userRepository: repository)
        let org = try JSONDecoder().decode(
            OrganizationSnapshot.self,
            from: JSONSerialization.data(withJSONObject: ["orgId": "orgY", "name": "Org Y"])
        )
        let success = await vm.select(org)
        #expect(!success)
        #expect(vm.errorMessage != nil)
    }
}
