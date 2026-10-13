//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 13/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

public struct SyncState: Codable, Sendable {
    public let entityName: String
    public var lastSyncTimestamp: Double
    
    public init(entityName: String, lastSyncTimestamp: Double = 0) {
        self.entityName = entityName
        self.lastSyncTimestamp = lastSyncTimestamp
    }
}

extension SyncState: SQLCodable {
    public static var table: SkipSQLCore.SQLTable {
        SQLTable(
            name: "SyncState",
            columns: [
                entityNameCol,
                lastSyncTimestampCol
            ]
        )
    }
    
    public init(row: SkipSQLCore.SQLRow, context: SkipSQLCore.SQLContext) throws {
        print("Decoding")
        let entityName = try Self.entityNameCol.textValueRequired(in: row)
        print("entityname \(entityName)")
        let lastSyncTimestamp = try Self.lastSyncTimestampCol.realValueRequired(in: row)
        print("lastSyncTimestamp \(lastSyncTimestamp)")
        
        self.init(
            entityName: entityName,
            lastSyncTimestamp: lastSyncTimestamp
        )
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.entityNameCol] = SQLValue(self.entityName)
        row[Self.lastSyncTimestampCol] = SQLValue(self.lastSyncTimestamp)
    }
    
    // SQLite column definitions
    public static let entityNameCol = SQLColumn(name: "entityName", type: .text, primaryKey: true)
    // TimeInterval is a Double in Swift, which maps to .real in SQLite
    public static let lastSyncTimestampCol = SQLColumn(name: "lastSyncTimestamp", type: .real)
}
