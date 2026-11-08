//
//  InventoryItemLocalStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL

public final actor InventoryItemLocalStorage: InventoryItemLocalStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getInventoryItems() throws -> [InventoryItem] {
        do {
            let items: [InventoryItem] = try database.context.fetchAll(InventoryItem.self)
            return items.filter { !$0.isDeleted }.sorted()
        } catch {
            print("SQL Error \(error.localizedDescription)")
            return []
        }
    }

    public func getInventoryItem(id: String) throws -> InventoryItem? {
        try database.context.fetch(InventoryItem.self, primaryKeys: [.text(id)])
    }

    public func saveInventoryItem(item: InventoryItem) throws {
        try database.context.insert(item, upsert: true)
    }

    public func updateInventoryItem(item: InventoryItem) throws {
        try database.context.insert(item, upsert: true)
    }

    public func deleteInventoryItem(id: String) throws {
        try database.context.delete(InventoryItem.self, where: InventoryItem.idCol.equals(SQLValue(id)))
    }

    public func markAsDeleted(id: String) throws {
        guard var item = try getInventoryItem(id: id) else { return }
        item.isDeleted = true
        item.updatedAt = Date()
        try database.context.insert(item, upsert: true)
    }

    public func saveInventoryItems(items: [InventoryItem]) throws {
        guard !items.isEmpty else { return }
        try database.context.transaction {
            for item in items {
                try database.context.insert(item, upsert: true)
            }
        }
    }
}
