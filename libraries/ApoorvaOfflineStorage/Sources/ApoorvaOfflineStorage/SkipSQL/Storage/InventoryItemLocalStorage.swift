//
//  CategoryLocalStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL

public final class InventoryItemLocalStorage: InventoryItemLocalStorageProtocol {
    
    private let database: SkipSqlDatabase
    
    public init(database: SkipSqlDatabase) {
        self.database = database
    }
    
    public func getInventoryItems() throws -> [InventoryItem] {
        let allCategories: [InventoryItem] = try database.context.fetchAll(InventoryItem.self)
        return allCategories.sorted { $0.name < $1.name }
    }
    
    public func getInventoryItem(id: String) throws -> InventoryItem? {
        return try database.context.fetch(InventoryItem.self, primaryKeys: [.text(id)])
    }
    
    public func saveInventoryItem(item: InventoryItem) throws {
        // skip-sql natively handles inserting SQLCodable types
        try database.context.insert(item)
    }
    
    public func updateInventoryItem(item: InventoryItem) throws {
        let query = """
        UPDATE Category 
        SET name = ?, currentStock = ?, billMachineNumber = ?, lastSoldDate = ?, isHotkey = ?, updatedAt = ?, isDeleted = ?
        WHERE id = ?;
        """
        
        // Convert Swift types to SQLite compatible Int64 and Double types
        let stock = Int64(item.currentStock)
        let billMachine = Int64(item.billMachineNumber)
        let isDeletedInt: Int64 = item.isDeleted ? 1 : 0
        let isHotkeyInt: Int64 = item.isHotkey ? 1 : 0        
        let lastSoldTime: SQLValue = item.lastSoldDate != nil ? .real(item.lastSoldDate!.timeIntervalSince1970) : .null
        let updatedTime: SQLValue = item.updatedAt != nil ? .real(item.updatedAt!.timeIntervalSince1970) : .null
        
        
        
        // Fix: Use 'sql:' and 'parameters:' labels, and wrap everything in SQLValue
        try database.context.exec(sql: query, parameters: [
            .text(item.id),
            .text(item.name),
            .long(stock),
            .long(billMachine),
            lastSoldTime,
            .long(isHotkeyInt),
            updatedTime,
            .long(isDeletedInt),
        ])
    }
    
    public func deleteInventoryItem(id: String) throws {
        let query = "DELETE FROM Category WHERE id = ?;"
        
        // Fix: Explicitly use sql: and parameters: [SQLValue]
        try database.context.exec(sql: query, parameters: [.text(id)])
    }
    
    public func markAsDeleted(id: String) throws {
        let query = "UPDATE Category SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        
        // Dates are typically stored as .real (timeInterval) or .text in skip-sql
        try database.context.exec(sql: query, parameters: [
            .real(Date().timeIntervalSince1970),
            .text(id)
        ])
    }
    
    public func saveInventoryItems(items: [InventoryItem]) throws {
            guard !items.isEmpty else { return }
            
            let query = """
            INSERT OR REPLACE INTO ItemCategory (
                id, name, currentStock, billMachineNumber, lastSoldDate, isHotkey, updatedAt, isDeleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            try database.context.exec(sql: "BEGIN TRANSACTION;")
            
            do {
                for item in items {
                    // Convert Swift types to SQLite compatible Int64 and Double types
                    let stock = Int64(item.currentStock)
                    let billMachine = Int64(item.billMachineNumber)
                    let isDeletedInt: Int64 = item.isDeleted ? 1 : 0
                    let isHotkeyInt: Int64 = item.isHotkey ? 1 : 0
                    let lastSoldTime: SQLValue = item.lastSoldDate != nil ? .real(item.lastSoldDate!.timeIntervalSince1970) : .null
                    let updatedTime: SQLValue = item.updatedAt != nil ? .real(item.updatedAt!.timeIntervalSince1970) : .null
                    
                    
                    
                    // Fix: Use 'sql:' and 'parameters:' labels, and wrap everything in SQLValue
                    try database.context.exec(sql: query, parameters: [
                        .text(item.id),
                        .text(item.name),
                        .long(stock),
                        .long(billMachine),
                        lastSoldTime,
                        .long(isHotkeyInt),
                        updatedTime,
                        .long(isDeletedInt),
                    ])
                }
                try database.context.exec(sql: "COMMIT;")
            } catch {
                try? database.context.exec(sql: "ROLLBACK;")
                throw error
            }
        }
}
