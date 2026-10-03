//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/07/26.
//


import ApoorvaModels
import GRDB

// 1. Tell GRDB that our enum can be stored as a String natively
extension AccountType: @retroactive DatabaseValueConvertible {}

// 2. Map the struct to the table. GRDB handles the columns automatically based on property names!
extension Account: @retroactive FetchableRecord, @retroactive MutablePersistableRecord, DatabaseMigratable {
    public static let databaseTableName = "Account"
    
    public static func createTable(in db: Database) throws {
            try db.create(table: databaseTableName) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("currentBalance", .double).notNull()
                
                t.column("updatedAt", .datetime).notNull()
                t.column("isDeleted", .boolean).notNull().defaults(to: false)
            }
        }
}
