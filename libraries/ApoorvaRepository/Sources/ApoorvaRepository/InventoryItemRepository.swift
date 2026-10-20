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
}


public final class InventoryItemRepository: InventoryItemRepositoryProtocol {

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
    }
    
    public func updateInventoryItem(_ item: InventoryItem) async throws {
        try await storage.updateInventoryItem(item: item)
    }
    
    public func deleteInventoryItem(id: String) async throws {
        try await storage.deleteInventoryItem(id: id)
    }
    
    public func markAsDeleted(id: String) async throws {
        try await storage.markAsDeleted(id: id)
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
            items = try await service.getInventoryItems(since: Date(timeIntervalSince1970: lastUpdatedDate), for: orgId)
            print("Received items")
        } else {
            print("Fetch all inventiry items \(orgId)")
            items = try await service.getInventoryItems(for: orgId)
        }
        print("Saving inventory items")
        try await storage.saveInventoryItems(items: items)
        guard
            let itemWithMinUpdatedAt = items.itemWithMaxDate
        else { return }
        
        print("item with min update \(itemWithMinUpdatedAt)")
        
        guard let lastUpdatedDate = itemWithMinUpdatedAt.updatedAt else { return }
        print("saving lastUpdatedDate \(lastUpdatedDate)")

        try await syncStorage.updateSyncTimestamp(for: InventoryItem.table.name, timestamp: lastUpdatedDate.timeIntervalSince1970)
    }
}


private extension Array where Element == InventoryItem {
    var itemWithMaxDate: InventoryItem? {
        self.max(by: {
            guard
                let lastUpdatedDateItem1 = $0.updatedAt,
                let lastUpdatedDateItem2 = $1.updatedAt
            else { return false }
            
            return lastUpdatedDateItem1 > lastUpdatedDateItem2
        })
    }
}
