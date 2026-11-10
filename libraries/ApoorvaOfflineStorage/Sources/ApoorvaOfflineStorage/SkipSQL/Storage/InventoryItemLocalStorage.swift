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

    public func getInventoryItems() async throws -> [InventoryItem] {
        do {
            let items: [InventoryItem] = try await database.withContext { context in
                try context.fetchAll(InventoryItem.self)
            }
            return items.filter { !$0.isDeleted }.sorted()
        } catch {
            print("SQL Error \(error.localizedDescription)")
            return []
        }
    }

    public func getInventoryItem(id: String) async throws -> InventoryItem? {
        try await database.withContext { context in
            try context.fetch(InventoryItem.self, primaryKeys: [.text(id)])
        }
    }

    public func saveInventoryItem(item: InventoryItem) async throws {
        try await database.withContext { context in
            try context.insert(item, upsert: true)
        }
    }

    public func updateInventoryItem(item: InventoryItem) async throws {
        try await database.withContext { context in
            try context.insert(item, upsert: true)
        }
    }

    public func deleteInventoryItem(id: String) async throws {
        try await database.withContext { context in
            try context.delete(InventoryItem.self, where: InventoryItem.idCol.equals(SQLValue(id)))
        }
    }

    public func markAsDeleted(id: String) async throws {
        guard var item = try await getInventoryItem(id: id) else { return }
        item.isDeleted = true
        item.updatedAt = Date()
        try await database.withContext { context in
            try context.insert(item, upsert: true)
        }
    }

    public func saveInventoryItems(items: [InventoryItem]) async throws {
        guard !items.isEmpty else { return }
        try await database.withContext { context in
            try context.transaction {
                for item in items {
                    try context.insert(item, upsert: true)
                }
            }
        }
    }
}
