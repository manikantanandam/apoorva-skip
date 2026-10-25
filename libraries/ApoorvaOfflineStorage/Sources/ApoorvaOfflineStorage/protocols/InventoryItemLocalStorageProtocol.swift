//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels

public protocol InventoryItemLocalStorageProtocol: Sendable {
    
    func getInventoryItems() async throws -> [InventoryItem]
    
    func saveInventoryItems(items: [InventoryItem]) async throws

    func saveInventoryItem(item: InventoryItem) async throws
    
    func getInventoryItem(id: String) async throws -> InventoryItem?
    
    func updateInventoryItem(item: InventoryItem) async throws
    
    func deleteInventoryItem(id: String) async throws // Hard delete
    
    func markAsDeleted(id: String) async throws  // Soft delete
}
