//
//  SyncStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL

public final actor SyncStorage: Sendable {
    private let db: SkipSqlDatabase

    public init(db: SkipSqlDatabase) {
        self.db = db
    }

    /// Fetches the last successful sync timestamp for a given entity collection (e.g., "InventoryItem").
    /// Returns 0 if the entity has never been synced.
    public func getLastSyncTimestamp(for entityName: String) throws -> TimeInterval? {
        print("Getting last sync date for \(entityName)")
        let entity = try db.context.fetch(SyncState.self, primaryKeys: [.text(entityName)])
        return entity?.lastSyncTimestamp
    }

    /// Upserts the sync timestamp for a given entity.
    /// Safely creates the row if it doesn't exist, or updates it if it does.
    public func updateSyncTimestamp(for entityName: String, timestamp: TimeInterval) throws {
        let query = """
        INSERT INTO \(SyncState.table.name) (entityName, lastSyncTimestamp) 
        VALUES (?, ?)
        ON CONFLICT(entityName) DO UPDATE SET lastSyncTimestamp = excluded.lastSyncTimestamp;
        """
        
        try db.context.exec(sql: query,
                            parameters: [
                                .text(entityName),
                                .real(timestamp)
                            ]
        )
    }

    /// Clears the sync state for a specific entity, forcing a full fetch on the next sync.
    public func resetSyncState(for entityName: String) throws {
        let query = "DELETE FROM \(SyncState.table.name) WHERE entityName = ?"
        try db.context.exec(sql: query, parameters: [
            .text(entityName)
        ])
    }
    
    /// Clears all sync states (Useful for when a user logs out or switches organizations).
    public func resetAllSyncStates() throws {
        let query = "DELETE FROM \(SyncState.table.name);"
        try db.context.exec(sql: query)
    }
}
