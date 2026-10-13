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
    func sync() async throws
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
        try storage.getInventoryItems()
    }
    
    public func saveInventoryItem(item: InventoryItem) async throws {
        try storage.saveInventoryItem(item: item)
    }
    
    public func updateInventoryItem(_ item: InventoryItem) async throws {
        try storage.updateInventoryItem(item: item)
    }
    
    public func deleteInventoryItem(id: String) async throws {
        try storage.deleteInventoryItem(id: id)
    }
    
    public func markAsDeleted(id: String) async throws {
        try storage.markAsDeleted(id: id)
    }
    
    public func sync() async throws {
        print("Started sync")
        let user = try await userRepository.getCurrentUser()
        print("Received used")
        let lastUpdatedDate = try syncStorage.getLastSyncTimestamp(for: InventoryItem.table.name)
        print("Last updted date \(lastUpdatedDate)")
        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        let items: [InventoryItem]
        if let lastUpdatedDate {
            print("Fetching inventory items since \(Date(timeIntervalSince1970: lastUpdatedDate)) for \(orgId)")
            items = try await service.getInventoryItems(since: Date(timeIntervalSince1970: lastUpdatedDate), for: orgId)
            print("Received items")
        } else {
            print("Fetch all inventiry items \(orgId)")
            items = try await service.getInventoryItems(for: orgId)
        }
        print("Saving inventory items")
        try storage.saveInventoryItems(items: items)
        guard
            let itemWithMinUpdatedAt = items.itemWithMaxDate
        else { return }
        
        print("item with min update \(itemWithMinUpdatedAt)")
        
        guard let lastUpdatedDate = itemWithMinUpdatedAt.updatedAt else { return }
        print("saving lastUpdatedDate \(lastUpdatedDate)")

        try syncStorage.updateSyncTimestamp(for: InventoryItem.table.name, timestamp: lastUpdatedDate.timeIntervalSince1970)
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
