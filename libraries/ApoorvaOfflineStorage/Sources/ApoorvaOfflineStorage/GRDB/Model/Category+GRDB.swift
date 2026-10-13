//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation
import ApoorvaModels
import GRDB

extension ApoorvaModels.InventoryItem: @retroactive FetchableRecord, @retroactive MutablePersistableRecord, DatabaseMigratable {
    public static let databaseTableName = "Category"
    
    public static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("currentStock", .integer).notNull()
            t.column("billMachineNumber", .integer).notNull()
            t.column("lastSoldDate", .datetime)
            t.column("isHotkey", .boolean).notNull()
            
            t.column("updatedAt", .datetime).notNull()
            t.column("isDeleted", .boolean).notNull().defaults(to: false)
        }
    }
}
