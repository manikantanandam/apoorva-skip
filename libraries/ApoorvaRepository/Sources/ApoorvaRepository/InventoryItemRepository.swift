//
//  File.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaModels
import ApoorvaServices

public protocol InventoryItemRepositoryProtocol: Sendable {
    func getInventoryItems() async throws -> [InventoryItem]
    func saveInventoryItem(item: InventoryItem) async throws
    func updateInventoryItem(_ item: InventoryItem) async throws
    func deleteInventoryItem(id: String) async throws // Hard delete
    func markAsDeleted(id: String) async throws  // Soft delete
    func sync(force: Bool) async throws
    func lastSyncedAt() async throws -> Date?
}


public final actor InventoryItemRepository: InventoryItemRepositoryProtocol {

    let storage: InventoryItemLocalStorageProtocol
    let service: InventoryItemServiceProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage
    
    public init(storage: InventoryItemLocalStorageProtocol,
                service: InventoryItemServiceProtocol,
                userRepository: UserRepositoryProtocol,
                syncStorage: SyncStorage) {
        self.storage = storage
        self.service = service
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }
    
    public func getInventoryItems() async throws -> [InventoryItem] {
        try await storage.getInventoryItems()
    }
    
    public func saveInventoryItem(item: InventoryItem) async throws {
        try await storage.saveInventoryItem(item: item)
        try await pushRemote(item)
    }

    public func updateInventoryItem(_ item: InventoryItem) async throws {
        try await storage.updateInventoryItem(item: item)
        try await pushRemote(item)
    }

    public func deleteInventoryItem(id: String) async throws {
        try await storage.deleteInventoryItem(id: id)
    }

    /// Soft delete, so other devices drop the item on their next sync.
    public func markAsDeleted(id: String) async throws {
        try await storage.markAsDeleted(id: id)
        if let item = try await storage.getInventoryItem(id: id) {
            try await pushRemote(item)
        }
    }

    private func pushRemote(_ item: InventoryItem) async throws {
        guard let orgId = try? await userRepository.getCurrentUser().selectedOrganization?.orgId else { return }
        try service.upsertInventoryItem(item, for: orgId)
    }

    public func lastSyncedAt() async throws -> Date? {
        guard let timestamp = try await syncStorage.getLastSyncTimestamp(for: InventoryItem.table.name) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    public func sync(force: Bool) async throws {
        print("Started sync")
        let user = try await userRepository.getCurrentUser()
        print("Received used")

        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        let items: [InventoryItem]
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: InventoryItem.table.name)
        print("Last updted date \(lastUpdatedDate)")
        
        if let lastUpdatedDate, !force {
            print("Fetching inventory items since \(Date(timeIntervalSince1970: lastUpdatedDate)) for \(orgId)")
            items = try await service.getInventoryItems(since: SyncCursor.queryStart(from: lastUpdatedDate), for: orgId)
            print("Received items")
        } else {
            print("Fetch all inventiry items \(orgId)")
            items = try await service.getInventoryItems(for: orgId)
        }
        print("Saving inventory items")
        try await storage.saveInventoryItems(items: items)
        // The query matches on updatedAt OR lastSoldDate, so the cursor tracks the newest of both.
        guard let latest = SyncCursor.latest(items.flatMap { [$0.updatedAt, $0.lastSoldDate] }) else { return }
        try await syncStorage.updateSyncTimestamp(for: InventoryItem.table.name, timestamp: latest.timeIntervalSince1970)
    }
}
