import GRDB
import Foundation
import ApoorvaModels

public final class AppDatabase {
    public let dbPool: DatabasePool
    
    public init(databaseURL: URL) throws {
        var configuration = Configuration()
        configuration.maximumReaderCount = 5
        
        dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)
        try migrator.migrate(dbPool)
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1_initial_schema") { db in
            // 1. Sync Engine Metadata
            try db.create(table: "SyncState") { t in
                t.column("collectionName", .text).primaryKey()
                t.column("lastSyncTimestamp", .datetime).notNull()
            }
            
            // 2. All Models
            try Account.createTable(in: db)
            try InternalTransfer.createTable(in: db)
            try Category.createTable(in: db)
            try Customer.createTable(in: db)
            try Organization.createTable(in: db)
            try AppUser.createTable(in: db)
            try Sale.createTable(in: db)
        }
        migrator.registerMigration("v2_cashflow_ledger") { db in
                    try db.create(table: "CashflowTransaction") { t in
                        t.column("id", .text).primaryKey()
                        t.column("timestamp", .datetime).notNull()
                        t.column("particulars", .text).notNull()
                        t.column("amount", .double).notNull()
                        t.column("transactionType", .text).notNull()
                        t.column("paymentMode", .text).notNull()
                        t.column("category", .text).notNull()
                        t.column("person", .text)
                        t.column("isDeleted", .boolean).notNull().defaults(to: false)
                        t.column("updatedAt", .datetime).notNull()
                    }
                }
        
        migrator.registerMigration("v3_cashflow_subcategory") { db in
                    try db.alter(table: "CashflowTransaction") { t in
                        t.add(column: "subCategory", .text)
                    }
                }
        
        return migrator
    }
}
