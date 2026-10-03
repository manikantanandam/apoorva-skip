//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/07/26.
//

import ApoorvaModels
import GRDB

extension InternalTransfer: @retroactive FetchableRecord, @retroactive MutablePersistableRecord, DatabaseMigratable {
    public static let databaseTableName = "InternalTransfer"
    
    public static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.column("id", .text).primaryKey()
            t.column("fromAccountId", .text).notNull().indexed()
            t.column("toAccountId", .text).notNull().indexed()
            t.column("amount", .double).notNull()
            t.column("transferType", .text).notNull()
            t.column("timestamp", .datetime).notNull()
            
            t.column("updatedAt", .datetime).notNull()
            t.column("isDeleted", .boolean).notNull().defaults(to: false)
        }
    }
}
