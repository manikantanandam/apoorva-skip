import ApoorvaModels
import GRDB

extension Customer: @retroactive FetchableRecord, @retroactive MutablePersistableRecord, DatabaseMigratable {
    public static let databaseTableName = "Customer"
    
    public static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName) { t in
            t.column("phone", .text).primaryKey() // Assuming phone is the unique ID here
            t.column("name", .text).notNull()
            t.column("createdAt", .datetime).notNull()
            t.column("lastPurchaseDate", .datetime)
            t.column("totalSales", .integer).notNull()
            t.column("totalAmountSpent", .double).notNull()
            
            t.column("updatedAt", .datetime).notNull()
            t.column("isDeleted", .boolean).notNull().defaults(to: false)
        }
    }
}
