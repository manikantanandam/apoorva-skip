//
//  InventoryItemRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
import ApoorvaServices
@testable import ApoorvaRepository

final class MockInventoryStorage: InventoryItemLocalStorageProtocol, @unchecked Sendable {
    var items: [InventoryItem] = []
    var calls: [String] = []

    func getInventoryItems() async throws -> [InventoryItem] { calls.append("get"); return items }
    func saveInventoryItems(items: [InventoryItem]) async throws { calls.append("saveMany"); self.items = items }
    func saveInventoryItem(item: InventoryItem) async throws { calls.append("save") }
    func getInventoryItem(id: String) async throws -> InventoryItem? { nil }
    func updateInventoryItem(item: InventoryItem) async throws { calls.append("update") }
    func deleteInventoryItem(id: String) async throws { calls.append("delete") }
    func markAsDeleted(id: String) async throws { calls.append("markDeleted") }
}

final class MockInventoryService: InventoryItemServiceProtocol, @unchecked Sendable {
    var result: [InventoryItem] = []
    var calls: [String] = []

    func getInventoryItems(for orgId: String) async throws -> [InventoryItem] {
        calls.append("all")
        return result
    }

    func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem] {
        calls.append("since")
        return result
    }
}

@MainActor
struct InventoryItemRepositoryTests {
    private func makeSUT(user: AppUser?) throws -> (InventoryItemRepository, MockInventoryStorage, MockInventoryService, SyncStorage) {
        let storage = MockInventoryStorage()
        let service = MockInventoryService()
        let userService = MockUserService()
        userService.user = user
        let userRepo = UserRepository(userDefaults: MockUserDefaultsStorage(),
                                      authService: StubAuthService(),
                                      userService: userService)
        let sync = SyncStorage(db: try SkipSqlDatabase(filepath: ":memory:"))
        return (InventoryItemRepository(storage: storage, service: service, userRepository: userRepo, syncStorage: sync),
                storage, service, sync)
    }

    @Test func crudDelegatesToStorage() async throws {
        let (sut, storage, _, _) = try makeSUT(user: nil)
        let item = InventoryItem(name: "Pen")
        try await sut.saveInventoryItem(item: item)
        try await sut.updateInventoryItem(item)
        try await sut.deleteInventoryItem(id: item.id)
        try await sut.markAsDeleted(id: item.id)
        _ = try await sut.getInventoryItems()
        #expect(storage.calls == ["save", "update", "delete", "markDeleted", "get"])
    }

    @Test func syncSkipsWithoutSelectedOrganization() async throws {
        let (sut, storage, service, _) = try makeSUT(user: try makeUser())
        try await sut.sync(force: false)
        #expect(service.calls.isEmpty)
        #expect(storage.calls.isEmpty)
    }

    @Test func firstSyncFetchesAllAndStoresTimestamp() async throws {
        let (sut, storage, service, sync) = try makeSUT(user: try makeUser(orgId: "org1"))
        service.result = [InventoryItem(name: "A", updatedAt: Date(timeIntervalSince1970: 300))]
        try await sut.sync(force: false)
        #expect(service.calls == ["all"])
        #expect(storage.items.count == 1)
        #expect(try await sync.getLastSyncTimestamp(for: InventoryItem.table.name) == 300)
    }

    @Test func syncWithNoItemsLeavesTimestampUntouched() async throws {
        let (sut, _, _, sync) = try makeSUT(user: try makeUser(orgId: "org1"))
        try await sut.sync(force: false)
        #expect(try await sync.getLastSyncTimestamp(for: InventoryItem.table.name) == nil)
    }

    @Test func incrementalAndForcedSync() async throws {
        let (sut, _, service, sync) = try makeSUT(user: try makeUser(orgId: "org1"))
        try await sync.updateSyncTimestamp(for: InventoryItem.table.name, timestamp: 50)
        try await sut.sync(force: false)
        try await sut.sync(force: true)
        #expect(service.calls == ["since", "all"])
    }
}
