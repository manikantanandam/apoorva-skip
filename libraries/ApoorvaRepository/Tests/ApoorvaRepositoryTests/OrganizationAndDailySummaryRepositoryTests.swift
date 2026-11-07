//
//  OrganizationAndDailySummaryRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
import ApoorvaServices
@testable import ApoorvaRepository

// MARK: - Organization mocks

final class MockOrganizationStorage: OrganizationStorageProtocol, @unchecked Sendable {
    var organizations: [Organization] = []
    var calls: [String] = []

    func getOrganizations() async throws -> [Organization] { calls.append("get"); return organizations }
    func getOrganization(orgId: String) async throws -> Organization? { organizations.first { $0.id == orgId } }
    func saveOrganization(organization: Organization) async throws { calls.append("save") }
    func updateOrganization(organization: Organization) async throws {}
    func deleteOrganization(orgId: String) async throws {}
    func markAsDeleted(orgId: String) async throws {}
    func saveOrganizations(organizations: [Organization]) async throws {
        calls.append("saveMany")
        self.organizations = organizations
    }
}

final class MockOrganizationService: OrganizationServiceProtocol, @unchecked Sendable {
    var orgs: [String: Organization] = [:]
    var calls: [String] = []
    var shouldThrow = false

    func getOrganization(for orgId: String) async throws -> Organization {
        if shouldThrow { throw TestError.failed }
        guard let org = orgs[orgId] else { throw TestError.failed }
        return org
    }

    func getOrganizations(since lastSync: Date, assignedIds: [String]) async throws -> [Organization] {
        calls.append("since")
        if shouldThrow { throw TestError.failed }
        return assignedIds.compactMap { orgs[$0] }
    }
}

func makeOrganization(id: String, updatedAt: TimeInterval = 100) -> Organization {
    Organization(id: id, name: id, status: "active", createdAt: Date(timeIntervalSince1970: 1),
                 minVersion: "1.0", currentTheme: "light", accentColor: "#000000", accounts: [],
                 updatedAt: Date(timeIntervalSince1970: updatedAt), establishedAtInMs: 1)
}

func makeAssignedUser(orgIds: [String]) throws -> AppUser {
    let orgs = orgIds.map { ["orgId": $0, "name": $0] }
    let data = try JSONSerialization.data(withJSONObject: ["id": "u1", "assignedOrgs": orgs])
    return try JSONDecoder().decode(AppUser.self, from: data)
}

@MainActor
struct OrganizationRepositoryTests {
    private func makeSUT(orgIds: [String]) throws -> (OrganizationRepository, MockOrganizationStorage, MockOrganizationService, SyncStorage) {
        let storage = MockOrganizationStorage()
        let service = MockOrganizationService()
        let sync = SyncStorage(db: try SkipSqlDatabase(filepath: ":memory:"))
        let user = try makeAssignedUser(orgIds: orgIds)
        return (OrganizationRepository(storage: storage, service: service,
                                       userRepository: makeUserRepository(user: user), syncStorage: sync),
                storage, service, sync)
    }

    @Test func syncWithNoAssignedOrgsDoesNothing() async throws {
        let (sut, storage, _, _) = try makeSUT(orgIds: [])
        try await sut.sync(force: false)
        #expect(storage.calls.isEmpty)
    }

    @Test func fullSyncFetchesEachAssignedOrgAndStoresTimestamp() async throws {
        let (sut, storage, service, sync) = try makeSUT(orgIds: ["a", "b"])
        service.orgs = ["a": makeOrganization(id: "a", updatedAt: 100), "b": makeOrganization(id: "b", updatedAt: 700)]
        try await sut.sync(force: false)
        #expect(storage.organizations.count == 2)
        #expect(try await sync.getLastSyncTimestamp(for: Organization.table.name) == 700)
    }

    @Test func fullSyncSkipsOrgsThatFail() async throws {
        let (sut, storage, service, _) = try makeSUT(orgIds: ["a", "missing"])
        service.orgs = ["a": makeOrganization(id: "a")]
        try await sut.sync(force: true)
        #expect(storage.organizations.map(\.id) == ["a"])
    }

    @Test func deltaSyncUsesSinceWhenTimestampExists() async throws {
        let (sut, storage, service, sync) = try makeSUT(orgIds: ["a"])
        service.orgs = ["a": makeOrganization(id: "a")]
        try await sync.updateSyncTimestamp(for: Organization.table.name, timestamp: 10)
        try await sut.sync(force: false)
        #expect(service.calls == ["since"])
        #expect(storage.organizations.count == 1)
    }

    @Test func deltaSyncSwallowsServiceError() async throws {
        let (sut, storage, service, sync) = try makeSUT(orgIds: ["a"])
        service.shouldThrow = true
        try await sync.updateSyncTimestamp(for: Organization.table.name, timestamp: 10)
        try await sut.sync(force: false)
        #expect(storage.organizations.isEmpty)
    }

    @Test func getOrganizationsSyncsWhenStorageEmpty() async throws {
        let (sut, _, service, _) = try makeSUT(orgIds: ["a"])
        service.orgs = ["a": makeOrganization(id: "a")]
        #expect(try await sut.getOrganizations().count == 1)
    }

    @Test func getOrganizationsReturnsStoredWithoutSync() async throws {
        let (sut, storage, service, _) = try makeSUT(orgIds: ["a"])
        storage.organizations = [makeOrganization(id: "x")]
        #expect(try await sut.getOrganizations().count == 1)
        #expect(service.calls.isEmpty)
    }

    @Test func getOrganizationFindsByIdAfterSync() async throws {
        let (sut, _, service, _) = try makeSUT(orgIds: ["a"])
        service.orgs = ["a": makeOrganization(id: "a")]
        #expect(try await sut.getOrganization(orgId: "a")?.id == "a")
        #expect(try await sut.getOrganization(orgId: "zzz") == nil)
    }

    @Test func saveOrganizationDelegatesToStorage() async throws {
        let (sut, storage, _, _) = try makeSUT(orgIds: [])
        try await sut.saveOrganization(organization: makeOrganization(id: "a"))
        #expect(storage.calls == ["save"])
    }
}

// MARK: - DailyCashflowSummary mocks

final class MockSummaryStorage: DailyCashflowSummaryStorageProtocol, @unchecked Sendable {
    var calls: [String] = []

    func getDailyCashflowSummaries() async throws -> [DailyCashflowSummary] { calls.append("getAll"); return [] }
    func getDailyCashflowSummary(id: String) async throws -> DailyCashflowSummary? { calls.append("get"); return nil }
    func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws { calls.append("save") }
    func updateDailyCashflowSummary(summary: DailyCashflowSummary) async throws { calls.append("update") }
    func deleteDailyCashflowSummary(id: String) async throws { calls.append("delete") }
    func saveDailyCashflowSummaries(summaries: [DailyCashflowSummary]) async throws { calls.append("saveMany") }
}

final class MockSummaryService: DailyCashflowSummaryServiceProtocol, @unchecked Sendable {
    var calls: [String] = []

    func getDailyCashflowSummaries(for orgId: String) async throws -> [DailyCashflowSummary] { calls.append("all"); return [] }
    func getDailyCashflowSummaries(since lastSync: Date, for orgId: String) async throws -> [DailyCashflowSummary] { calls.append("since"); return [] }
    func getDailyCashflowSummary(orgId: String, date: String) async throws -> DailyCashflowSummary { calls.append("fetch:\(date)"); return makeSummary() }
    func addDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws { calls.append("add") }
    func updateDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws { calls.append("updateRemote") }
}

func makeSummary() -> DailyCashflowSummary {
    DailyCashflowSummary(date: Date(timeIntervalSince1970: 0), openingBalances: [], closingBalances: [],
                         updatedAt: 1, locked: false)
}

@MainActor
struct DailyCashflowSummaryRepositoryTests {
    private func makeSUT(user: AppUser?) throws -> (DailyCashflowSummaryRepository, MockSummaryStorage, MockSummaryService, SyncStorage) {
        let storage = MockSummaryStorage()
        let service = MockSummaryService()
        let sync = SyncStorage(db: try SkipSqlDatabase(filepath: ":memory:"))
        return (DailyCashflowSummaryRepository(storage: storage, service: service,
                                               userRepository: makeUserRepository(user: user), syncStorage: sync),
                storage, service, sync)
    }

    @Test func readsAndDeletesDelegateToStorage() async throws {
        let (sut, storage, _, _) = try makeSUT(user: nil)
        _ = try await sut.getDailyCashflowSummaries()
        _ = try await sut.getDailyCashflowSummary(id: "1")
        try await sut.deleteDailyCashflowSummary(id: "1")
        #expect(storage.calls == ["getAll", "get", "delete"])
    }

    @Test func saveWritesRemoteOnly() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sut.saveDailyCashflowSummary(summary: makeSummary())
        #expect(service.calls == ["add"])
        #expect(storage.calls.isEmpty)
    }

    @Test func updateWritesRemoteAndLocal() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sut.updateDailyCashflowSummary(summary: makeSummary())
        #expect(service.calls == ["updateRemote"])
        #expect(storage.calls == ["update"])
    }

    @Test func writesAreNoOpsWithoutOrganization() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser())
        try await sut.saveDailyCashflowSummary(summary: makeSummary())
        try await sut.updateDailyCashflowSummary(summary: makeSummary())
        try await sut.sync(force: true)
        try await sut.refresh(for: "01-01-2026")
        #expect(service.calls.isEmpty)
        #expect(storage.calls.isEmpty)
    }

    @Test func syncFetchesAllThenSinceAndRecordsTimestamp() async throws {
        let (sut, storage, service, sync) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sut.sync(force: false)
        try await sut.sync(force: false)
        try await sut.sync(force: true)
        #expect(service.calls == ["all", "since", "all"])
        #expect(storage.calls == ["saveMany", "saveMany", "saveMany"])
        #expect(try await sync.getLastSyncTimestamp(for: DailyCashflowSummary.table.name) != nil)
    }

    @Test func refreshFetchesAndSavesSummary() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser(orgId: "o"))
        try await sut.refresh(for: "01-01-2026")
        #expect(service.calls == ["fetch:01-01-2026"])
        #expect(storage.calls == ["save"])
    }
}
