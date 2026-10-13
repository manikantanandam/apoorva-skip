//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

@preconcurrency import SkipSQL
import Foundation
import ApoorvaModels

public final class SkipSqlDatabase: @unchecked Sendable {
    public let context: SQLContext
    
    public init(filepath: String) throws {
        
        self.context = try SQLContext(
            path: filepath, flags: [.create, .readWrite],
            configuration: .platform
        )
        try createTables()
    }
    
    /// Call this once during app initialization
        public func createTables() throws {
            // Skip-SQL uses the SQLCodable conformance to automatically generate the schema
            try context.createTableIfNotExists(InventoryItem.self)
            try context.createTableIfNotExists(SyncState.self)

            // Add other models here:
            // try context.createTableIfNotExists(Account.self)
            // try context.createTableIfNotExists(Sale.self)
        }
}
