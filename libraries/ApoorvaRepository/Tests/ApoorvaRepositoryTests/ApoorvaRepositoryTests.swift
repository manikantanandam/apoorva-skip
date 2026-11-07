//
//  ApoorvaRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
import ApoorvaServices
@testable import ApoorvaRepository

// MARK: - Mocks

final class MockUserDefaultsStorage: UserDefaultsStorageProtocol, @unchecked Sendable {
    var store: [String: Data] = [:]

    func set<T: Encodable>(_ object: T, forKey key: String) throws {
        store[key] = try JSONEncoder().encode(object)
    }

    func get<T: Decodable>(forKey key: String, as type: T.Type) throws -> T? {
        guard let data = store[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func remove(forKey key: String) {
        store[key] = nil
    }
}

struct StubAuthService: AuthServicing {
    var currentUserStream: AsyncStream<AppUser?> { AsyncStream { $0.finish() } }
    func login(email: String, password: String) async throws {}
    func logout() throws {}
}

final class MockUserService: UserServiceProtocol, @unchecked Sendable {
    var user: AppUser?
    var updatedOrgs: [String] = []
    var shouldThrow = false
    var listUsersResult: [AppUser] = []
    var updatedRoles: [(id: String, role: AppUserRole)] = []

    var userSessionStream: AsyncStream<AppUser?> { AsyncStream { $0.finish() } }
    var currentUser: AppUser? { user }

    func updateSelectedOrganization(for user: AppUser, organization: OrganizationSnapshot) async throws {
        if shouldThrow { throw TestError.failed }
        updatedOrgs.append(organization.orgId)
    }

    func listUsers(orgId: String) async throws -> [AppUser] {
        if shouldThrow { throw TestError.failed }
        return listUsersResult
    }

    func updateRole(userId: String, role: AppUserRole) async throws {
        if shouldThrow { throw TestError.failed }
        updatedRoles.append((userId, role))
    }
}

enum TestError: Error { case failed }

final class MockCustomerStorage: CustomerStorageProtocol, @unchecked Sendable {
    var customers: [Customer] = []
    var calls: [String] = []

    func getCustomers() async throws -> [Customer] { calls.append("getCustomers"); return customers }
    func saveCustomers(customers: [Customer]) async throws { calls.append("saveCustomers"); self.customers = customers }
    func saveCustomer(customer: Customer) async throws { calls.append("saveCustomer") }
    func getCustomer(phoneNumber: String) async throws -> Customer? { nil }
    func getCustomer(name: String) async throws -> Customer? { nil }
    func updateCustomer(customer: Customer) async throws { calls.append("updateCustomer") }
    func deleteCustomer(phoneNumber: String) async throws { calls.append("deleteCustomer") }
    func markAsDeleted(id: String) async throws { calls.append("markAsDeleted") }
}

final class MockCustomerService: CustomerServiceProtocol, @unchecked Sendable {
    var result: [Customer] = []
    var calls: [String] = []

    func getCustomers(for orgId: String) async throws -> [Customer] {
        calls.append("all")
        return result
    }

    func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer] {
        calls.append("since")
        return result
    }
}

// MARK: - Helpers

func makeUser(id: String = "u1", orgId: String? = nil) throws -> AppUser {
    var json: [String: Any] = ["id": id, "name": "Test", "email": "t@t.com"]
    if let orgId {
        json["selectedOrganization"] = ["orgId": orgId, "name": "Org"]
    }
    let data = try JSONSerialization.data(withJSONObject: json)
    return try JSONDecoder().decode(AppUser.self, from: data)
}

func makeOrg(_ id: String = "org1") throws -> OrganizationSnapshot {
    let data = try JSONSerialization.data(withJSONObject: ["orgId": id, "name": "Org"])
    return try JSONDecoder().decode(OrganizationSnapshot.self, from: data)
}

func makeCustomer(name: String = "A", lastPurchase: TimeInterval? = 100, updatedAt: TimeInterval? = 200) -> Customer {
    Customer(name: name, phone: "123", createdAt: 1, lastPurchaseDate: lastPurchase,
             totalSales: 1, totalAmountSpent: 10, updatedAt: updatedAt, isDeleted: false)
}

// MARK: - UserRepository

@MainActor
struct UserRepositoryTests {
    private func makeSUT(user: AppUser? = nil) -> (UserRepository, MockUserDefaultsStorage, MockUserService) {
        let defaults = MockUserDefaultsStorage()
        let service = MockUserService()
        service.user = user
        return (UserRepository(userDefaults: defaults, authService: StubAuthService(), userService: service), defaults, service)
    }

    @Test func getCurrentUserReturnsServiceUser() async throws {
        let user = try makeUser()
        let (sut, _, _) = makeSUT(user: user)
        #expect(try await sut.getCurrentUser().id == "u1")
    }

    @Test func getCurrentUserThrowsWhenMissing() async {
        let (sut, _, _) = makeSUT()
        await #expect(throws: UserError.self) { try await sut.getCurrentUser() }
    }

    @Test func setGetAndDeleteUser() async throws {
        let (sut, _, _) = makeSUT()
        let user = try makeUser(id: "u2")
        try await sut.setUser(user: user)
        #expect(try await sut.getUser(id: "u2")?.id == "u2")
        try await sut.updateUser(user: user)
        await sut.deleteUser(id: "u2")
        #expect(try await sut.getUser(id: "u2") == nil)
    }

    @Test func updateSelectedOrganizationCallsServiceAndCaches() async throws {
        let (sut, defaults, service) = makeSUT()
        let user = try makeUser(id: "u3")
        try await sut.updateSelectedOrganization(for: user, organization: makeOrg("orgX"))
        #expect(service.updatedOrgs == ["orgX"])
        #expect(defaults.store["user_u3"] != nil)
    }

    @Test func updateSelectedOrganizationPropagatesServiceError() async throws {
        let (sut, defaults, service) = makeSUT()
        service.shouldThrow = true
        await #expect(throws: TestError.self) {
            try await sut.updateSelectedOrganization(for: makeUser(id: "u4"), organization: makeOrg())
        }
        #expect(defaults.store["user_u4"] == nil)
    }

    @Test func listUsersDelegatesToService() async throws {
        let (sut, _, service) = makeSUT()
        service.listUsersResult = [try makeUser(id: "member1")]
        let users = try await sut.listUsers(orgId: "orgX")
        #expect(users.map(\.id) == ["member1"])
    }

    @Test func listUsersPropagatesServiceError() async throws {
        let (sut, _, service) = makeSUT()
        service.shouldThrow = true
        await #expect(throws: TestError.self) { try await sut.listUsers(orgId: "orgX") }
    }

    @Test func updateUserRoleDelegatesToService() async throws {
        let (sut, _, service) = makeSUT()
        try await sut.updateUserRole(id: "member1", role: .admin)
        #expect(service.updatedRoles.map(\.id) == ["member1"])
        #expect(service.updatedRoles.map(\.role) == [.admin])
    }

    @Test func updateUserRolePropagatesServiceError() async throws {
        let (sut, _, service) = makeSUT()
        service.shouldThrow = true
        await #expect(throws: TestError.self) { try await sut.updateUserRole(id: "member1", role: .admin) }
    }
}

// MARK: - CustomerRepository

@MainActor
struct CustomerRepositoryTests {
    private func makeSUT(user: AppUser?) throws -> (CustomerRepository, MockCustomerStorage, MockCustomerService, SyncStorage) {
        let storage = MockCustomerStorage()
        let service = MockCustomerService()
        let userService = MockUserService()
        userService.user = user
        let userRepo = UserRepository(userDefaults: MockUserDefaultsStorage(),
                                      authService: StubAuthService(),
                                      userService: userService)
        let sync = SyncStorage(db: try SkipSqlDatabase(filepath: ":memory:"))
        return (CustomerRepository(storage: storage, service: service, userRepository: userRepo, syncStorage: sync),
                storage, service, sync)
    }

    @Test func crudDelegatesToStorage() async throws {
        let (sut, storage, _, _) = try makeSUT(user: nil)
        let customer = makeCustomer()
        try await sut.saveCustomer(customer: customer)
        try await sut.updateCustomer(customer)
        try await sut.deleteCustomer(phoneNumber: "123")
        try await sut.markAsDeleted(id: "id")
        _ = try await sut.getCustomers()
        #expect(storage.calls == ["saveCustomer", "updateCustomer", "deleteCustomer", "markAsDeleted", "getCustomers"])
    }

    @Test func syncThrowsWithoutUser() async throws {
        let (sut, _, _, _) = try makeSUT(user: nil)
        await #expect(throws: UserError.self) { try await sut.sync(force: false) }
    }

    @Test func syncSkipsWithoutSelectedOrganization() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser())
        try await sut.sync(force: false)
        #expect(service.calls.isEmpty)
        #expect(storage.calls.isEmpty)
    }

    @Test func firstSyncFetchesAllAndStoresTimestamp() async throws {
        let (sut, storage, service, sync) = try makeSUT(user: try makeUser(orgId: "org1"))
        service.result = [makeCustomer(name: "A", lastPurchase: 100, updatedAt: 500)]
        try await sut.sync(force: false)
        #expect(service.calls == ["all"])
        #expect(storage.customers.count == 1)
        #expect(try await sync.getLastSyncTimestamp(for: Customer.table.name) == 500)
    }

    @Test func incrementalSyncFetchesSinceLastTimestamp() async throws {
        let (sut, _, service, sync) = try makeSUT(user: try makeUser(orgId: "org1"))
        try await sync.updateSyncTimestamp(for: Customer.table.name, timestamp: 50)
        try await sut.sync(force: false)
        #expect(service.calls == ["since"])
    }

    @Test func forcedSyncIgnoresTimestamp() async throws {
        let (sut, _, service, sync) = try makeSUT(user: try makeUser(orgId: "org1"))
        try await sync.updateSyncTimestamp(for: Customer.table.name, timestamp: 50)
        try await sut.sync(force: true)
        #expect(service.calls == ["all"])
    }
}
