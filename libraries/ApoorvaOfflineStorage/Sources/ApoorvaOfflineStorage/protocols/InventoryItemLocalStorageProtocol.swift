//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels

public protocol InventoryItemLocalStorageProtocol: Sendable {
    
    func getInventoryItems() throws -> [InventoryItem]
    
    func saveInventoryItems(items: [InventoryItem]) throws 

    func saveInventoryItem(item: InventoryItem) throws
    
    func getInventoryItem(id: String) throws -> InventoryItem?
    
    func updateInventoryItem(item: InventoryItem) throws
    
    func deleteInventoryItem(id: String) throws // Hard delete
    
    func markAsDeleted(id: String) throws  // Soft delete
}
